module Fastlane
  module Actions
    class TestsFromTestResultAction < Action
      def self.run(params)
        test_summaries_plist_filepath = File.join(
          params[:test_result],
          'TestSummaries.plist'
        )
        test_summaries_file = REXML::Document.new(File.read(test_summaries_plist_filepath))
        activity_summaries = REXML::XPath.match(test_summaries_file, '//*[string/text() = "IDESchemeActionTestSummary"]')
        passing_tests = []
        failing_tests = []
        skipped_tests = []
        activity_summaries.each do |activity_summary|
          test_identifier = REXML::XPath.first(activity_summary, 'key[text() = "TestIdentifier"]/following-sibling::*[1]').text
          test_identifier.delete_suffix!('()')

          test_status = test_status = REXML::XPath.first(activity_summary, 'key[text() = "TestStatus"]/following-sibling::*[1]').text
          passing_tests.append(test_identifier) if test_status == 'Success'
          failing_tests.append(test_identifier) if test_status == 'Failure'
          skipped_tests.append(test_identifier) if test_status == 'Skipped'
        end

        {
          :passing => passing_tests,
          :failed => failing_tests,
          :skipped => skipped_tests
        }
      end

      def self.description
        "☑️ Retrieves the failing, passing, and skipped tests as reported in a test_result bundle"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :test_result,
            env_name: 'FL_TESTS_FROM_TEST_RESULT_PATH',
            description: 'The path to the test_result bundle to retrieve the tests from',
            verify_block: proc do |path|
              UI.user_error!("Error: cannot find the test_result bundle at '#{path}'") unless Dir.exist?(path)
              UI.user_error!("Error: cannot parse files that are not in the test_result format") unless File.extname(path) == '.test_result'
            end
          )
        ]
      end

      def self.return_value
        "A Hash with information about the test results:\r\n" \
        "failed: an Array of the failed test identifiers\r\n" \
        "passing: an Array of the passing test identifiers\r\n" \
        "skipped: an Array of the skipped test identifiers\r\n"
      end

      def self.authors
        ['lyndsey-ferguson/lyndseydf']
      end

      def self.category
        :testing
      end

      def self.is_supported?(platform)
        %i[ios mac].include?(platform)
      end
    end
  end
end

