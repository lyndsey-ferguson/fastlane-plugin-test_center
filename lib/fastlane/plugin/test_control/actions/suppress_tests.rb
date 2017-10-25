module Fastlane
  module Actions
    module SharedValues
      SUPPRESS_TESTS_CUSTOM_VALUE = :SUPPRESS_TESTS_CUSTOM_VALUE
    end

    class SuppressTestsAction < Action
      require 'xcodeproj'

      def self.run(params)
        project_path = params[:xcodeproj]
        tests_to_skip = params[:tests]

        scheme_filepaths = Dir.glob("#{project_path}/{xcshareddata,xcuserdata}/**/xcschemes/*.xcscheme")
        scheme_filepaths.each do |scheme_filepath|
          is_dirty = false
          xcscheme = Xcodeproj::XCScheme.new(scheme_filepath)
          xcscheme.test_action.testables.each do |testable|
            tests_to_skip.each do |test_to_skip|
              skipped_test = Xcodeproj::XCScheme::TestAction::TestableReference::SkippedTest.new
              skipped_test.identifier = test_to_skip
              testable.add_skipped_test(skipped_test)
              is_dirty = true
            end
          end
          xcscheme.save! if is_dirty
        end
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "A short description with <= 80 characters of what this action does"
      end

      def self.details
        # Optional:
        # this is your chance to provide a more detailed description of this action
        "You can use this action to do cool things..."
      end

      def self.available_options
        # Define all options your action supports.

        # Below a few examples
        [
          FastlaneCore::ConfigItem.new(
            key: :xcodeproj,
            env_name: "FL_SUPPRESS_TESTS_XCODE_PROJECT", # The name of the environment variable
            description: "The file path to the Xcode project file to modify", # a short description of this parameter
            verify_block: proc do |path|
              UI.user_error!("Error: Xcode project file path not given!") unless path and !path.empty?
              UI.user_error!("Error: Xcode project '#{path}' not found!") unless Dir.exist?(path)
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :tests,
            env_name: "FL_SUPPRESS_TESTS_TESTS_TO_SUPPRESS", # The name of the environment variable
            description: "A list of tests to suppress", # a short description of this parameter
            verify_block: proc do |tests|
              UI.user_error!("Error: no tests were given to suppress!") unless tests and !tests.empty?
              tests.each do |test_identifier|
                is_valid_test_identifier = %r{^[a-zA-Z][a-zA-Z0-9]+(\/test[a-zA-Z0-9]+)?$} =~ test_identifier
                unless is_valid_test_identifier
                  UI.user_error!("Error: invalid test identifier '#{test_identifier}'. It must be in the format of 'TestSuiteToSuppress' or 'TestSuiteToSuppress/testToSuppress'")
                end
              end
            end,
            type: Array
          )
        ]
      end

      def self.output
        # Define the shared values you are going to provide
        # Example
        [
          ['SUPPRESS_TESTS_CUSTOM_VALUE', 'A description of what this value contains']
        ]
      end

      def self.return_value
        # If your method provides a return value, you can describe here what it does
      end

      def self.authors
        # So no one will ever forget your contribution to fastlane :) You are awesome btw!
        ["Your GitHub/Twitter Name"]
      end

      def self.is_supported?(platform)
        # you can do things like
        #
        #  true
        #
        #  platform == :ios
        #
        #  [:ios, :mac].include?(platform)
        #

        platform == :ios
      end
    end
  end
end
