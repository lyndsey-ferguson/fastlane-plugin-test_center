module Fastlane
  module Actions
    module SharedValues
      SUPPRESSED_TESTS_CUSTOM_VALUE = :SUPPRESSED_TESTS_CUSTOM_VALUE
    end

    class SuppressedTestsAction < Action
      require 'set'

      def self.run(params)
        project_path = params[:xcodeproj]
        scheme = params[:scheme]

        scheme_filepaths = Dir.glob("#{project_path}/{xcshareddata,xcuserdata}/**/xcschemes/#{scheme || '*'}.xcscheme")
        if scheme_filepaths.length.zero?
          UI.user_error!("Error: cannot find any scheme named #{scheme}") unless scheme.nil?
          UI.user_error!("Error: cannot find any schemes in the Xcode project")
        end

        skipped_tests = Set.new
        scheme_filepaths.each do |scheme_filepath|
          xcscheme = Xcodeproj::XCScheme.new(scheme_filepath)
          xcscheme.test_action.testables.each do |testable|
            testable.skipped_tests.map do |skipped_test|
              skipped_tests.add(skipped_test.identifier)
            end
          end
        end
        skipped_tests.to_a
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
            env_name: "FL_SUPPRESSED_TESTS_XCODE_PROJECT", # The name of the environment variable
            description: "The file path to the Xcode project file to read the skipped tests from", # a short description of this parameter
            verify_block: proc do |path|
              UI.user_error!("Error: Xcode project file path not given!") unless path and !path.empty?
              UI.user_error!("Error: Xcode project '#{path}' not found!") unless Dir.exist?(path)
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :scheme,
            optional: true,
            env_name: "FL_SUPPRESSED_TESTS_SCHEME_TO_UPDATE", # The name of the environment variable
            description: "The Xcode scheme where the suppressed tests may be", # a short description of this parameter
            verify_block: proc do |scheme_name|
              UI.user_error!("Error: Xcode Scheme '#{scheme_name}' is not valid!") if scheme_name and scheme_name.empty?
            end
          )
        ]
      end

      def self.output
        # Define the shared values you are going to provide
        # Example
        [
          ['SUPPRESSED_TESTS_CUSTOM_VALUE', 'A description of what this value contains']
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
