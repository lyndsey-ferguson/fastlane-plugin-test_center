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
        if @only_testing.kind_of?(String)
          @only_testing = @only_testing.split(',')
        end
        @skip_testing = options[:skip_testing]
        @invocation_based_tests = options[:invocation_based_tests]
        @batch_count = options[:batch_count]
        if @batch_count == 1 && options[:parallel_testrun_count] > 1
          @batch_count = options[:parallel_testrun_count]
        end
      end

      def default_derived_data_path(options)
        project_derived_data_path = Scan.project.build_settings(key: "BUILT_PRODUCTS_DIR")
        File.expand_path("../../..", project_derived_data_path)
      end

      def derived_testrun_path(derived_data_path, scheme)
        xctestrun_files = Dir.glob("#{derived_data_path}/Build/Products/*.xctestrun")
        xctestrun_files.sort { |f1, f2| File.mtime(f1) <=> File.mtime(f2) }.last
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

      def xctestrun_known_tests
        config = FastlaneCore::Configuration.create(
          ::Fastlane::Actions::TestsFromXctestrunAction.available_options,
          {
            xctestrun: @xctestrun_path,
            invocation_based_tests: @invocation_based_tests
          }
        )
        ::Fastlane::Actions::TestsFromXctestrunAction.run(config)
      end

      def expand_testsuites_to_tests
        return if @invocation_based_tests

        known_tests = []
        @testables_tests.each do |testable, tests|
          tests.each_with_index do |test, index|
            if test.count('/') < 2
              known_tests += xctestrun_known_tests[testable]
              test_components = test.split('/')
              testsuite = test_components.size == 1 ? test_components[0] : test_components[1]
              @testables_tests[testable][index] = known_tests.select { |known_test| known_test.include?(testsuite) } 
            end
          end
          @testables_tests[testable].flatten!
        end
      end

      def testables_tests
        unless @testables_tests
          if @only_testing
            @testables_tests = only_testing_to_testables_tests
            expand_testsuites_to_tests
          else
            @testables_tests = xctestrun_known_tests
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
              slice_count = [(testable_tests.length / @batch_count.to_f).ceil, 1].max
              testable_tests.each_slice(slice_count).to_a.each do |tests_batch|
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
