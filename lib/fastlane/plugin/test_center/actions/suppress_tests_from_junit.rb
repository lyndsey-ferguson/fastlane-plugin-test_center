module Fastlane
  module Actions
    class SuppressTestsFromJunitAction < Action
      def self.run(params)
        project_path = params[:xcodeproj]
        scheme = params[:scheme]

        scheme_filepaths = Dir.glob("#{project_path}/{xcshareddata,xcuserdata}/**/xcschemes/#{scheme || '*'}.xcscheme")
        if scheme_filepaths.length.zero?
          UI.user_error!("Error: cannot find any scheme named #{scheme}") unless scheme.nil?
          UI.user_error!("Error: cannot find any schemes in the Xcode project")
        end

        testables = Hash.new([])
        desired_passed_status = (params[:suppress_type] == :passing)

        report = ::TestCenter::Helper::XcodeJunit::Report.new(params[:junit])

        report.testables.each do |testable|
          testables[testable.name] = []
          testable.testsuites.each do |testsuite|
            testsuite.testcases.each do |testcase|
              if testcase.passed? == desired_passed_status
                testables[testable.name] << testcase.skipped_test
              end
            end
          end
        end

        scheme_filepaths.each do |scheme_filepath|
          is_dirty = false
          xcscheme = Xcodeproj::XCScheme.new(scheme_filepath)

          xcscheme.test_action.testables.each do |testable|
            buildable_name = testable.buildable_references[0].buildable_name
            testables[buildable_name].each do |skipped_test|
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
      
      # :nocov:
      def self.description
        "🗜 Uses a junit xml report file to suppress either passing or failing tests in an Xcode Scheme"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :xcodeproj,
            env_name: "FL_SUPPRESS_TESTS_FROM_JUNIT_XCODE_PROJECT",
            description: "The file path to the Xcode project file to modify",
            verify_block: proc do |path|
              UI.user_error!("Error: Xcode project file path not given!") unless path and !path.empty?
              UI.user_error!("Error: Xcode project '#{path}' not found!") unless Dir.exist?(path)
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :junit,
            env_name: "FL_SUPPRESS_TESTS_FROM_JUNIT_JUNIT_REPORT",
            description: "The junit xml report file from which to collect the tests to suppress",
            verify_block: proc do |path|
              UI.user_error!("Error: cannot find the junit xml report file '#{path}'") unless File.exist?(path)
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :scheme,
            optional: true,
            env_name: "FL_SUPPRESS_TESTS_FROM_JUNIT_SCHEME_TO_UPDATE",
            description: "The Xcode scheme where the tests should be suppressed",
            verify_block: proc do |scheme_name|
              UI.user_error!("Error: Xcode Scheme '#{scheme_name}' is not valid!") if scheme_name and scheme_name.empty?
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :suppress_type,
            type: Symbol,
            env_name: "FL_SUPPRESS_TESTS_FROM_JUNIT_SUPPRESS_TYPE",
            description: "Tests to suppress are either :failed or :passing",
            verify_block: proc do |type|
              UI.user_error!("Error: suppress type ':#{type}' is invalid! Only :failed or :passing are valid types") unless %i[failed passing].include?(type)
            end
          )
        ]
      end

      def self.example_code
        [
          "
          UI.important(
            'example: ' \\
            'suppress the tests that failed in the junit report for _all_ Schemes'
          )
          suppress_tests_from_junit(
            xcodeproj: 'AtomicBoy/AtomicBoy.xcodeproj',
            junit: './spec/fixtures/junit.xml',
            suppress_type: :failed
          )
          UI.message(
            \"Suppressed tests for project: \#{suppressed_tests(xcodeproj: 'AtomicBoy/AtomicBoy.xcodeproj')}\"
          )
          ",
          "
          UI.important(
            'example: ' \\
            'suppress the tests that failed in the junit report for _one_ Scheme'
          )
          suppress_tests_from_junit(
            xcodeproj: 'AtomicBoy/AtomicBoy.xcodeproj',
            junit: './spec/fixtures/junit.xml',
            scheme: 'Professor',
            suppress_type: :failed
          )
          UI.message(
            \"Suppressed tests for the 'Professor' scheme: \#{suppressed_tests(xcodeproj: 'AtomicBoy/AtomicBoy.xcodeproj')}\"
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
