module Fastlane
  module Actions
    class TestplansFromSchemeAction < Action
      def self.run(params)
        scheme_filepaths = schemes(params)
        testplan_paths = []
        scheme_filepaths.each do |scheme_filepath|
          UI.verbose("Looking in Scheme '#{scheme_filepath}' for any testplans")
          xcscheme = Xcodeproj::XCScheme.new(scheme_filepath)
          next unless scheme_has_testplans?(xcscheme)
          scheme_container_dir = File.absolute_path(scheme_filepath).sub(%r{/[^/]*\.(xcworkspace|xcodeproj)/.*}, '')
          xcscheme.test_action.test_plans.each do |testplan|
            testplan_path = File.absolute_path(File.join(scheme_container_dir, testplan.target_referenced_container.sub('container:', '')))
            UI.verbose("  found testplan '#{testplan_path}'")
            testplan_paths << testplan_path
          end
        end
        testplan_paths
      end

      def self.scheme_has_testplans?(xcscheme)
          return !(
            xcscheme.test_action.nil? ||
            xcscheme.test_action.testables.to_a.empty? ||
            xcscheme.test_action.testables[0].buildable_references.to_a.empty? ||
            xcscheme.test_action.test_plans.to_a.empty?
          )
      end

      def self.schemes(params)
        scheme = params[:scheme]
        scheme_filepaths = schemes_from_project(params[:xcodeproj], scheme) || schemes_from_workspace(params[:workspace], scheme)
        if scheme_filepaths.length.zero?
          scheme_detail_message = ''
          if scheme
            scheme_detail_message = "named '#{scheme}' "
          end
          UI.user_error!("Error: cannot find any schemes #{scheme_detail_message}in the Xcode project") if params[:xcodeproj]
          UI.user_error!("Error: cannot find any schemes #{scheme_detail_message}in the Xcode workspace") if params[:workspace]
        end
        scheme_filepaths
      end

      def self.schemes_from_project(project_path, scheme)
        return nil unless project_path

        Dir.glob("#{project_path}/{xcshareddata,xcuserdata}/**/xcschemes/#{scheme || '*'}.xcscheme")
      end

      def self.schemes_from_workspace(workspace_path, scheme)
        return nil unless workspace_path

        scheme_filepaths = []
        scheme_filepaths.concat(schemes_from_project(workspace_path, scheme))
        return scheme_filepaths unless scheme_filepaths.empty?

        xcworkspace = Xcodeproj::Workspace.new_from_xcworkspace(workspace_path)
        xcodeprojects = xcworkspace.file_references.select do |file_reference|
          file_reference.path.end_with?('xcodeproj')
        end

        xcodeprojects.each do |file_reference|
          next if file_reference.path.include?('Pods/Pods.xcodeproj')

          project_path = file_reference.absolute_path(File.dirname(workspace_path))
          scheme_filepaths.concat(schemes_from_project(project_path, scheme))
        end
        scheme_filepaths
      end

      def self.description
        "☑️Gets all the testplans that a Scheme references"
      end

      def self.authors
        ["lyndsey-ferguson/lyndseydf"]
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :xcodeproj,
            env_name: "FL_TESTPLANS_FROM_SCHEME_XCODE_PROJECT",
            optional: true,
            description: "The file path to the Xcode project file that references the Scheme",
            verify_block: proc do |path|
              path = File.expand_path(path.to_s)
              UI.user_error!("Error: Xcode project file path not given!") unless path and !path.empty?
              UI.user_error!("Error: Xcode project '#{path}' not found!") unless Dir.exist?(path)
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :workspace,
            env_name: "FL_TESTPLANS_FROM_SCHEME_XCODE_WORKSPACE",
            optional: true,
            description: "The file path to the Xcode workspace file that references the Scheme",
            verify_block: proc do |value|
              v = File.expand_path(value.to_s)
              UI.user_error!("Error: Workspace file not found at path '#{v}'") unless Dir.exist?(v)
              UI.user_error!("Error: Workspace file is not a workspace, must end with .xcworkspace") unless v.include?(".xcworkspace")
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :scheme,
            optional: true,
            env_name: "FL_TESTPLANS_FROM_SCHEME_XCODE_SCHEME",
            description: "The Xcode scheme referencing the testplan",
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
            'get all the testplans that an Xcode Scheme references'
          )
          testplans = testplans_from_scheme(
            xcodeproj: 'AtomicBoy/AtomicBoy.xcodeproj',
            scheme: 'AtomicBoy'
          )
          UI.message(\"The AtomicBoy uses the following testplans: \#{testplans}\")
          "
        ]
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
