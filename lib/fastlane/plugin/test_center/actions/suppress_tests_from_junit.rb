module Fastlane
  module Actions
    module SharedValues
      SUPPRESS_TESTS_FROM_JUNIT_CUSTOM_VALUE = :SUPPRESS_TESTS_FROM_JUNIT_CUSTOM_VALUE
    end

    class SuppressTestsFromJunitAction < Action
      def self.run(params)
        project_path = params[:xcodeproj]
        scheme = params[:scheme]

        scheme_filepaths = Dir.glob("#{project_path}/{xcshareddata,xcuserdata}/**/xcschemes/#{scheme || '*'}.xcscheme")
        if scheme_filepaths.length.zero?
          UI.user_error!("Error: cannot find any scheme named #{scheme}") unless scheme.nil?
          UI.user_error!("Error: cannot find any schemes in the Xcode project")
        end

        report_file = File.open(params[:junit]) { |f| REXML::Document.new(f) }
        UI.user_error!("Malformed XML test report file given") if report_file.root.nil?
        UI.user_error!("Valid XML file is not an Xcode test report") if report_file.get_elements('testsuites').empty?

        if params[:suppress_type] == :failed
          tests_per_target_to_suppress = failing_tests(report_file)
        else
          tests_per_target_to_suppress = passing_tests(report_file)
        end

        scheme_filepaths.each do |scheme_filepath|
          is_dirty = false
          xcscheme = Xcodeproj::XCScheme.new(scheme_filepath)

          xcscheme.test_action.testables.each do |testable|
            buildable_name = testable.buildable_references[0].buildable_name

            tests_per_target_to_suppress[buildable_name].each do |test_to_skip|
              skipped_test = Xcodeproj::XCScheme::TestAction::TestableReference::SkippedTest.new
              skipped_test.identifier = test_to_skip
              testable.add_skipped_test(skipped_test)
              is_dirty = true
            end
          end
          xcscheme.save! if is_dirty
        end
      end

      def self.failing_tests(report_file)
        tests = Hash.new { |hash, key| hash[key] = [] }

        report_file.elements.each('*/testsuite/testcase/failure') do |failure_element|
          testcase = failure_element.parent
          testsuite_element = testcase.parent
          buildable_name = buildable_name_from_testcase(testcase)

          tests[buildable_name] << xctest_identifier(testcase)
          # Remove all the failures from this in-memory xml file to make
          # it easier to find the passing tests below
          testsuite_element.delete_element testcase
        end
        tests
      end

      def self.passing_tests(report_file)
        tests = Hash.new { |hash, key| hash[key] = [] }

        report_file.elements.each('*/testsuite/testcase') do |testcase|
          buildable_name = buildable_name_from_testcase(testcase)

          tests[buildable_name] << xctest_identifier(testcase)
        end
        tests
      end

      def self.buildable_name_from_testcase(testcase)
        testsuite_element = testcase.parent
        buildable_element = testsuite_element.parent
        buildable_element.attributes['name']
      end

      def self.xctest_identifier(testcase)
        testcase_class = testcase.attributes['classname']
        testcase_testmethod = testcase.attributes['name']

        is_swift = testcase_class.include?('.')
        testcase_class.gsub!(/.*\./, '')
        testcase_testmethod << '()' if is_swift
        "#{testcase_class}/#{testcase_testmethod}"
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Uses a junit xml report file to suppress either passing or failing tests in an Xcode Scheme"
      end

      def self.details
        "To be added"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :xcodeproj,
            env_name: "FL_SUPPRESS_TESTS_FROM_JUNIT_XCODE_PROJECT", # The name of the environment variable
            description: "The file path to the Xcode project file to modify", # a short description of this parameter
            verify_block: proc do |path|
              UI.user_error!("Error: Xcode project file path not given!") unless path and !path.empty?
              UI.user_error!("Error: Xcode project '#{path}' not found!") unless Dir.exist?(path)
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :junit,
            env_name: "FL_SUPPRESS_TESTS_FROM_JUNIT_JUNIT_REPORT", # The name of the environment variable
            description: "The junit xml report file from which to collect the tests to suppress",
            verify_block: proc do |path|
              UI.user_error!("Error: cannot find the junit xml report file '#{path}'") unless File.exist?(path)
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :scheme,
            optional: true,
            env_name: "FL_SUPPRESS_TESTS_FROM_JUNIT_SCHEME_TO_UPDATE", # The name of the environment variable
            description: "The Xcode scheme where the tests should be suppressed", # a short description of this parameter
            verify_block: proc do |scheme_name|
              UI.user_error!("Error: Xcode Scheme '#{scheme_name}' is not valid!") if scheme_name and scheme_name.empty?
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :suppress_type,
            type: Symbol,
            env_name: "FL_SUPPRESS_TESTS_FROM_JUNIT_SUPPRESS_TYPE", # The name of the environment variable
            description: "Tests to suppress are either :failed or :passing", # a short description of this parameter
            verify_block: proc do |type|
              UI.user_error!("Error: suppress type ':#{type}' is invalid! Only :failed or :passing are valid types") unless %i[failed passing].include?(type)
            end
          )
        ]
      end

      def self.authors
        ["lyndsey-ferguson/@ldferguson"]
      end

      def self.is_supported?(platform)
        platform == :ios
      end
    end
  end
end
