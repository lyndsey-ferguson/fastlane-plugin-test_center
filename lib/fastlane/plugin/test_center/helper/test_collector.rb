module TestCenter
  module Helper
    require 'fastlane_core/ui/ui.rb'
    require 'fastlane/actions/scan'
    require 'plist'

    class TestCollector
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
            @testables ||= Plist.parse_xml(@xctestrun_path).keys.reject do |retrievedTestable| 
              Fastlane::Actions::TestsFromXctestrunAction.ignoredTestables.include?(retrievedTestable)
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

      def testables_tests(invocation_based_tests)
        unless @testables_tests
          if @only_testing
            @testables_tests = only_testing_to_testables_tests
          else
            config = FastlaneCore::Configuration.create(::Fastlane::Actions::TestsFromXctestrunAction.available_options, xctestrun: @xctestrun_path, invocation_based_tests: invocation_based_tests)
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
    end
  end
end
