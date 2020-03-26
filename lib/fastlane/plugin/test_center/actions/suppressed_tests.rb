module Fastlane
  module Actions
    class SuppressedTestsAction < Action
      require 'set'
      require 'json'

      def self.run(params)
        scheme = params[:scheme]
        scheme_filepaths = schemes_from_project(params[:xcodeproj], scheme) || schemes_from_workspace(params[:workspace], scheme)
        if scheme_filepaths.length.zero?
          UI.user_error!("Error: cannot find any scheme named #{scheme}") unless scheme.nil?
          UI.user_error!("Error: cannot find any schemes in the Xcode project") if params[:xcodeproj]
          UI.user_error!("Error: cannot find any schemes in the Xcode workspace") if params[:workspace]
        end

        skipped_tests = Set.new
        scheme_filepaths.each do |scheme_filepath|
          xcscheme = Xcodeproj::XCScheme.new(scheme_filepath)
          testplans = xcscheme.test_action.test_plans
          unless testplans.nil?
            UI.important("Error: unable to read suppressed tests from Xcode Scheme #{File.basename(scheme_filepath)}.")
            UI.message("The scheme is using a testplan which does not list skipped tests.")
          else
            xcscheme.test_action.testables.each do |testable|
              buildable_name = testable.buildable_references[0]
                                       .buildable_name

              buildable_name = File.basename(buildable_name, '.xctest')
              testable.skipped_tests.map do |skipped_test|
                skipped_tests.add("#{buildable_name}/#{skipped_test.identifier}")
              end
            end
          end
        end
        skipped_tests.to_a
      end

      def self.schemes_from_project(project_path, scheme)
        return nil unless project_path

        Dir.glob("#{project_path}/{xcshareddata,xcuserdata}/**/xcschemes/#{scheme || '*'}.xcscheme")
      end

      def self.schemes_from_workspace(workspace_path, scheme)
        return nil unless workspace_path

        xcworkspace = Xcodeproj::Workspace.new_from_xcworkspace(workspace_path)
        scheme_filepaths = []
        xcworkspace.file_references.each do |file_reference|
          next if file_reference.path.include?('Pods/Pods.xcodeproj')

          project_path = file_reference.absolute_path(File.dirname(workspace_path))
          scheme_filepaths.concat(schemes_from_project(project_path, scheme))
        end
        scheme_filepaths
      end

      #####################################################
      # @!group Documentation
      #####################################################

      # :nocov:
      def self.description
        "🗜 Retrieves a list of tests that are suppressed in a specific or all Xcode Schemes in a project"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :xcodeproj,
            env_name: "FL_SUPPRESSED_TESTS_XCODE_PROJECT",
            optional: true,
            description: "The file path to the Xcode project file to read the skipped tests from",
            verify_block: proc do |path|
              UI.user_error!("Error: Xcode project file path not given!") unless path and !path.empty?
              UI.user_error!("Error: Xcode project '#{path}' not found!") unless Dir.exist?(path)
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :workspace,
            env_name: "FL_SUPPRESSED_TESTS_XCODE_WORKSPACE",
            optional: true,
            description: "The file path to the Xcode workspace file to read the skipped tests from",
            verify_block: proc do |value|
              v = File.expand_path(value.to_s)
              UI.user_error!("Workspace file not found at path '#{v}'") unless Dir.exist?(v)
              UI.user_error!("Workspace file invalid") unless File.directory?(v)
              UI.user_error!("Workspace file is not a workspace, must end with .xcworkspace") unless v.include?(".xcworkspace")
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :scheme,
            optional: true,
            env_name: "FL_SUPPRESSED_TESTS_SCHEME_TO_UPDATE",
            description: "The Xcode scheme where the suppressed tests may be",
            verify_block: proc do |scheme_name|
              UI.user_error!("Error: Xcode Scheme '#{scheme_name}' is not valid!") if scheme_name and scheme_name.empty?
            end
          )
        ]
      end

      def self.example_code
        [
          "
          UI.important(
            'example: ' \\
            'get the tests that are suppressed in a Scheme in the Project'
          )
          tests = suppressed_tests(
            xcodeproj: 'AtomicBoy/AtomicBoy.xcodeproj',
            scheme: 'AtomicBoy'
          )
          UI.message(\"Suppressed tests for scheme: \#{tests}\")
          ",
          "
          UI.important(
            'example: ' \\
            'get the tests that are suppressed in all Schemes in the Project'
          )
          UI.message(
            \"Suppressed tests for project: \#{suppressed_tests(xcodeproj: 'AtomicBoy/AtomicBoy.xcodeproj')}\"
          )
          ",
          "
          UI.important(
            'example: ' \\
            'get the tests that are suppressed in all Schemes in a workspace'
          )
          tests = suppressed_tests(
            workspace: File.absolute_path('../AtomicBoy/AtomicBoy.xcworkspace'),
            scheme: 'Professor'
          )
          UI.message(\"tests: \#{tests}\")
          "
        ]
      end

      def self.authors
        ["lyndsey-ferguson/@lyndseydf"]
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
