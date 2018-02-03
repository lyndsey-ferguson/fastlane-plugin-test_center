module Fastlane
  module Actions
    class TestsFromJunitAction < Action
      def self.run(params)
        unless Helper.test?
          FastlaneCore::PrintTable.print_values(
            config: params._values,
            title: "Summary for tests_from_junit (test_center v#{Fastlane::TestCenter::VERSION})"
          )
        end

        report = ::TestCenter::Helper::XcodeJunit::Report.new(params[:junit])
        passing = []
        failed = []
        report.testables.each do |testable|
          testable.testsuites.each do |testsuite|
            testsuite.testcases.each do |testcase|
              if testcase.passed?
                passing << testcase.identifier
              else
                failed << testcase.identifier
              end
            end
          end
        end
        {
          failed: failed,
          passing: passing
        }
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Retrieves the failing and passing tests as reported in a junit xml file"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :junit,
            env_name: "FL_SUPPRESS_TESTS_FROM_JUNIT_JUNIT_REPORT", # The name of the environment variable
            description: "The junit xml report file from which to collect the tests to suppress",
            verify_block: proc do |path|
              UI.user_error!("Error: cannot find the junit xml report file '#{path}'") unless File.exist?(path)
            end
          )
        ]
      end

      def self.return_value
        "A Hash with an Array of :passing and :failed tests"
      end

      def self.authors
        ["lyndsey-ferguson/lyndseydf"]
      end

      def self.is_supported?(platform)
        platform == :ios
      end
    end
  end
end
