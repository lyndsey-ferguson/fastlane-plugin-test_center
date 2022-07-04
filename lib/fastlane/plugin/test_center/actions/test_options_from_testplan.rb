require 'json'

module Fastlane
  module Actions
    class TestOptionsFromTestplanAction < Action
      def self.run(params)
        testplan_path = params[:testplan]

        testplan = JSON.parse(File.open(testplan_path).read)
        only_testing = []
        skip_testing = []
        UI.verbose("Examining testplan JSON: #{testplan}")
        testplan['testTargets'].each do |test_target|
          testable = test_target.dig('target', 'name')
          if test_target.key?('selectedTests')
            UI.verbose("  Found selectedTests")
            test_target['selectedTests'].each do |selected_test|
              selected_test.delete!('()')
              UI.verbose("    Found test: '#{selected_test}'")
              only_testing << "#{testable}/#{selected_test.sub('\/', '/')}"
            end
          end
          if test_target.key?('skippedTests')
            UI.verbose("  Found skippedTests")
            test_target['skippedTests'].each do |skipped_test|
              skipped_test.delete!('()')
              UI.verbose("    Found test: '#{skipped_test}'")
              skip_testing << "#{testable}/#{skipped_test.sub('\/', '/')}"
            end
          end
          unless test_target.key?('selectedTests') || test_target.key?('skippedTests')
            UI.verbose("  No selected or skipped tests, using testable '#{testable}'")
            only_testing << testable
          end
        end
        {
          code_coverage: testplan.dig('defaultOptions', 'codeCoverage'),
          only_testing: only_testing,
          skip_testing: skip_testing
        }
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "☑️ Gets test info from a given test plan"
      end

      def self.details
        "Gets tests info consisting of tests to run and whether or not code coverage is enabled"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :testplan,
            optional: true,
            env_name: "FL_TEST_OPTIONS_FROM_TESTPLAN_TESTPLAN",
            description: "The Xcode testplan to read the test info from",
            verify_block: proc do |test_plan|
              UI.user_error!("Error: Xcode Test Plan '#{test_plan}' is not valid!") if test_plan and test_plan.empty?
              UI.user_error!("Error: Test Plan does not exist at path '#{test_plan}'") unless File.exist?(test_plan)
            end
          )
        ]
      end

      def self.return_value
        "Returns a Hash with keys :code_coverage, :only_testing, and :skip_testing for the given testplan"
      end

      def self.example_code
        [
          "
          UI.important(
            'example: ' \\
            'get the tests and the test coverage configuration from a given testplan'
          )
          test_options = test_options_from_testplan(
            testplan: 'AtomicBoy/AtomicBoy_2.xctestplan'
          )
          UI.message(\"The AtomicBoy_2 testplan has the following tests: \#{test_options[:only_testing]}\")
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
    end
  end
end
