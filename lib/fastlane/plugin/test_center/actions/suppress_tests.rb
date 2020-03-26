module Fastlane
  module Actions
    class SuppressTestsAction < Action
      require 'xcodeproj'

      def self.run(params)
        all_tests_to_skip = params[:tests]
        scheme = params[:scheme]

        scheme_filepaths = schemes_from_project(params[:xcodeproj], scheme) || schemes_from_workspace(params[:workspace], scheme)
        if scheme_filepaths.length.zero?
          UI.user_error!("Error: cannot find any scheme named #{scheme}") unless scheme.nil?
          UI.user_error!("Error: cannot find any schemes in the Xcode project") if params[:xcodeproj]
          UI.user_error!("Error: cannot find any schemes in the Xcode workspace") if params[:workspace]
        end

        scheme_filepaths.each do |scheme_filepath|
          is_dirty = false
          xcscheme = Xcodeproj::XCScheme.new(scheme_filepath)
          testplans = xcscheme.test_action.test_plans
          unless testplans.nil?
            container_directory = File.absolute_path(File.dirname(params[:xcodeproj] || params[:workspace]))
            update_testplans(container_directory, testplans, all_tests_to_skip)
          else
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
          end
          xcscheme.save! if is_dirty
        end
        nil
      end

      def self.update_testplans(container_directory, testplans, all_tests_to_skip)
        testplans.each do |testplan_reference|
          testplan_filename = testplan_reference.target_referenced_container.sub('container:', '')
          testplan_filepath = File.join(container_directory, testplan_filename)
          file = File.read(testplan_filepath)
          testplan = JSON.parse(file)
          testplan['testTargets'].each do |test_target|
            buildable_name = test_target.dig('target', 'name')
            tests_to_skip = all_tests_to_skip.select { |test| test.start_with?(buildable_name) }
              .map { |test| test.sub("#{buildable_name}/", '') }
            test_target['selectedTests'].reject! { |t| tests_to_skip.include?(t) }
          end
          File.open(testplan_filepath, 'w') do |f|
            f.write(JSON.pretty_generate(testplan).gsub('/', '\/'))
          end
        end
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
        "🗜 Suppresses specific tests in a specific or all Xcode Schemes in a given project"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :xcodeproj,
            env_name: "FL_SUPPRESS_TESTS_XCODE_PROJECT",
            optional: true,
            description: "The file path to the Xcode project file to modify",
            verify_block: proc do |path|
              UI.user_error!("Error: Xcode project file path not given!") unless path and !path.empty?
              UI.user_error!("Error: Xcode project '#{path}' not found!") unless Dir.exist?(path)
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :workspace,
            env_name: "FL_SUPPRESS_TESTS_XCODE_WORKSPACE",
            optional: true,
            description: "The file path to the Xcode workspace file to modify",
            verify_block: proc do |value|
              v = File.expand_path(value.to_s)
              UI.user_error!("Workspace file not found at path '#{v}'") unless Dir.exist?(v)
              UI.user_error!("Workspace file invalid") unless File.directory?(v)
              UI.user_error!("Workspace file is not a workspace, must end with .xcworkspace") unless v.include?(".xcworkspace")
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

      def self.example_code
        [
          "
          UI.important(
            'example: ' \\
            'suppress some tests in all Schemes for a Project'
          )
          suppress_tests(
            xcodeproj: 'AtomicBoy/AtomicBoy.xcodeproj',
            tests: [
              'AtomicBoyUITests/HappyNapperTests/testBeepingNonExistentFriendDisplaysError',
              'AtomicBoyUITests/GrumpyWorkerTests'
            ]
          )
          ",
          "
          UI.important(
            'example: ' \\
            'suppress some tests in one Scheme for a Project'
          )
          suppress_tests(
            xcodeproj: 'AtomicBoy/AtomicBoy.xcodeproj',
            tests: [
              'AtomicBoyUITests/HappyNapperTests/testBeepingNonExistentFriendDisplaysError',
              'AtomicBoyUITests/GrumpyWorkerTests'
            ],
            scheme: 'Professor'
          )
          ",
          "
          UI.important(
            'example: ' \\
            'suppress some tests in one Scheme from a workspace'
          )
          suppress_tests(
            workspace: 'AtomicBoy/AtomicBoy.xcworkspace',
            tests: [
              'AtomicBoyUITests/HappyNapperTests/testBeepingNonExistentFriendDisplaysError',
              'AtomicBoyUITests/GrumpyWorkerTests'
            ],
            scheme: 'Professor'
          )
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
