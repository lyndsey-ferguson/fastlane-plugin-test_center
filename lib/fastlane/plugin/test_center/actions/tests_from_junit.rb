module Fastlane
  module Actions
    class TestsFromJunitAction < Action
      def self.run(params)
        report_file = File.open(params[:junit]) { |f| REXML::Document.new(f) }
        UI.user_error!("Malformed XML test report file given") if report_file.root.nil?
        UI.user_error!("Valid XML file is not an Xcode test report") if report_file.get_elements('testsuites').empty?

        {
          passing: passing_tests(report_file).to_a,
          failed: failing_tests(report_file).to_a
        }
      end

      def self.failing_tests(report_file)
        tests = Set.new

        report_file.elements.each('*/testsuite/testcase/failure') do |failure_element|
          testcase = failure_element.parent
          tests << xctest_identifier(testcase)
        end
        tests
      end

      def self.passing_tests(report_file)
        tests = Set.new

        report_file.elements.each('*/testsuite/testcase[not(failure)]') do |testcase|
          tests << xctest_identifier(testcase)
        end
        tests
      end

      def self.xctest_identifier(testcase)
        testcase_class = testcase.attributes['classname']
        testcase_testmethod = testcase.attributes['name']

        testcase_class.gsub!(/.*\./, '')
        "#{testcase_class}/#{testcase_testmethod}"
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Get the failing and passing tests as reported in a junit xml file"
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
        ["lyndsey-ferguson/ldferguson"]
      end

      def self.is_supported?(platform)
        platform == :ios
      end
    end
  end
end
