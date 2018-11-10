module TestCenter
  module Helper
    require 'fastlane_core/ui/ui.rb'
    require 'fastlane/actions/scan'
    require 'plist'

    class TestCollector
      attr_reader :xctestrun_path

      def initialize(options)
        unless options[:xctestrun] || options[:derived_data_path]
          options[:derived_data_path] = default_derived_data_path(options)
        end
        @xctestrun_path = options[:xctestrun] || derived_testrun_path(options[:derived_data_path], options[:scheme])
        unless @xctestrun_path && File.exist?(@xctestrun_path)
          FastlaneCore::UI.user_error!("Error: cannot find xctestrun file '#{@xctestrun_path}'")
        end
        @only_testing = options[:only_testing]
        @skip_testing = options[:skip_testing]
        @batch_count = options[:batch_count]
      end

      def default_derived_data_path(options)
        Scan.project = FastlaneCore::Project.new(
          options.select { |k, v| %i[workspace project].include?(k) }
        )
        project_derived_data_path = Scan.project.build_settings(key: "BUILT_PRODUCTS_DIR")
        File.expand_path("../../..", project_derived_data_path)
      end

      def derived_testrun_path(derived_data_path, scheme)
        Dir.glob("#{derived_data_path}/Build/Products/#{scheme}*.xctestrun").first
      end

      def testables
        unless @testables
          if @only_testing
            @testables ||= only_testing_to_testables_tests.keys
          else
            @testables ||= Plist.parse_xml(@xctestrun_path).keys.reject do |key|
              key == '__xctestrun_metadata__'
            end
          end
        end
        @testables
      end

      def only_testing_to_testables_tests
        tests = Hash.new { |h, k| h[k] = [] }
        @only_testing.sort.each do |test_identifier|
          testable = test_identifier.split('/', 2)[0]
          tests[testable] << test_identifier
        end
        tests
      end

      def testables_tests
        unless @testables_tests
          if @only_testing
            @testables_tests = only_testing_to_testables_tests
          else
            config = FastlaneCore::Configuration.create(::Fastlane::Actions::TestsFromXctestrunAction.available_options, xctestrun: @xctestrun_path)
            @testables_tests = ::Fastlane::Actions::TestsFromXctestrunAction.run(config)
            if @skip_testing
              skipped_testable_tests = Hash.new { |h, k| h[k] = [] }
              @skip_testing.sort.each do |skipped_test_identifier|
                testable = skipped_test_identifier.split('/', 2)[0]
                skipped_testable_tests[testable] << skipped_test_identifier
              end
              @testables_tests.each_key do |testable|
                @testables_tests[testable] -= skipped_testable_tests[testable]
              end
            end
          end
        end
        @testables_tests
      end

      def test_batches
        if @batches.nil?
          @batches = []
          testables.each do |testable|
            testable_tests = testables_tests[testable]
            next if testable_tests.empty?

            if @batch_count > 1
              testable_tests.each_slice((testable_tests.length / @batch_count.to_f).round).to_a.each do |tests_batch|
                @batches << tests_batch
              end
            else
              @batches << testable_tests
            end
          end
        end

        @batches
      end
    end
  end
end
