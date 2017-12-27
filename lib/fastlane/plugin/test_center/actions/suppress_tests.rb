module Fastlane
  module Actions
    class SuppressTestsAction < Action
      require 'xcodeproj'

      def self.run(params)
        project_path = params[:xcodeproj]
        all_tests_to_skip = params[:tests]
        scheme = params[:scheme]

        scheme_filepaths = Dir.glob("#{project_path}/{xcshareddata,xcuserdata}/**/xcschemes/#{scheme || '*'}.xcscheme")
        if scheme_filepaths.length.zero?
          UI.user_error!("Error: cannot find any scheme named #{scheme}") unless scheme.nil?
          UI.user_error!("Error: cannot find any schemes in the Xcode project")
        end

        scheme_filepaths.each do |scheme_filepath|
          is_dirty = false
          xcscheme = Xcodeproj::XCScheme.new(scheme_filepath)
          xcscheme.test_action.testables.each do |testable|
            buildable_name = File.basename(testable.buildable_references[0].buildable_name, '.xctest')

            tests_to_skip = all_tests_to_skip.select { |test| test.start_with?(buildable_name) }
                                             .map { |test| test.sub("#{buildable_name}/", '') }

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
        "Suppresses specific tests in a specific or all Xcode Schemes in a given project"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :xcodeproj,
            env_name: "FL_SUPPRESS_TESTS_XCODE_PROJECT",
            description: "The file path to the Xcode project file to modify",
            verify_block: proc do |path|
              UI.user_error!("Error: Xcode project file path not given!") unless path and !path.empty?
              UI.user_error!("Error: Xcode project '#{path}' not found!") unless Dir.exist?(path)
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :tests,
            env_name: "FL_SUPPRESS_TESTS_TESTS_TO_SUPPRESS",
            description: "A list of tests to suppress",
            verify_block: proc do |tests|
              UI.user_error!("Error: no tests were given to suppress!") unless tests and !tests.empty?
              tests.each do |test_identifier|
                is_valid_test_identifier = %r{^[a-zA-Z][a-zA-Z0-9]+\/[a-zA-Z][a-zA-Z0-9]+(\/test[a-zA-Z0-9]+)?$} =~ test_identifier
                unless is_valid_test_identifier
                  UI.user_error!("Error: invalid test identifier '#{test_identifier}'. It must be in the format of 'Testable/TestSuiteToSuppress' or 'Testable/TestSuiteToSuppress/testToSuppress'")
                end
              end
            end,
            type: Array
          ),
          FastlaneCore::ConfigItem.new(
            key: :scheme,
            optional: true,
            env_name: "FL_SUPPRESS_TESTS_SCHEME_TO_UPDATE",
            description: "The Xcode scheme where the tests should be suppressed",
            verify_block: proc do |scheme_name|
              UI.user_error!("Error: Xcode Scheme '#{scheme_name}' is not valid!") if scheme_name and scheme_name.empty?
            end
          )
        ]
      end

      def self.authors
        ["lyndsey-ferguson/@lyndseydf"]
      end

      def self.is_supported?(platform)
        platform == :ios
      end
    end
  end
end
