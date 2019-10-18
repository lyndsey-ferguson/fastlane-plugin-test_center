module Fastlane
  module Actions
    class TestsFromJunitAction < Action
      def self.run(params)
        report = ::TestCenter::Helper::XcodeJunit::Report.new(params[:junit])
        passing = []
        failed = []
        failure_details = {}
        report.testables.each do |testable|
          testable.testsuites.each do |testsuite|
            testsuite.testcases.each do |testcase|
              if testcase.passed?
                passing << testcase.identifier
              else
                failed << testcase.identifier
                failure_details[testcase.identifier] = {
                  message: testcase.message,
                  location: testcase.location
                }
              end
            end
          end
        end
        {
          failed: failed,
          passing: passing,
          failure_details: failure_details
        }
      end

      #####################################################
      # @!group Documentation
      #####################################################

      # :nocov:
      def self.description
        "☑️ Retrieves the failing and passing tests as reported in a junit xml file"
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
        "A Hash with information about the test results:\r\n" \
        "failed: an Array of the failed test identifiers\r\n" \
        "passing: an Array of the passing test identifiers\r\n" \
        "failure_details: a Hash with failed test identifiers as the key, and " \
        "a Hash with :message and :location details for the failed test"
      end

      def self.example_code
        [
          "
          UI.important(
            'example: ' \\
            'get the failed and passing tests from the junit test report file'
          )
          result = tests_from_junit(junit: './spec/fixtures/junit.xml')
          UI.message(\"Passing tests: \#{result[:passing]}\")
          UI.message(\"Failed tests: \#{result[:failed]}\")
          "
        ]
      end

      def self.authors
        ["lyndsey-ferguson/lyndseydf"]
      end

      def self.category
        :testing
      end

      def self.is_supported?(platform)
        %i[ios mac].include?(platform)
      end
      # :nocov:
    end
  end
end
