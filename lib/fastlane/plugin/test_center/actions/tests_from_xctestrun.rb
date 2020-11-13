require 'plist'

module Fastlane
  module Actions
    class TestsFromXctestrunAction < Action
      def self.run(params)
        UI.verbose("Getting tests from xctestrun file at '#{params[:xctestrun]}'")
        return xctestrun_tests(params[:xctestrun], params[:invocation_based_tests], swift_test_prefix: params[:swift_test_prefix])
      end

      def self.xctestrun_tests(xctestrun_path, invocation_based_tests, swift_test_prefix: "test")
        xctestrun = Plist.parse_xml(xctestrun_path)
        xctestrun_rootpath = File.dirname(xctestrun_path)
        xctestrun_version = xctestrun.fetch('__xctestrun_metadata__', Hash.new).fetch('FormatVersion', 1)

        test_targets = []
        if xctestrun_version == 1
          xctestrun.each do |testable_name, test_target_config|
            next if ignoredTestables.include? testable_name
            test_target_config['TestableName'] = testable_name
            test_targets << test_target_config
          end
        else
          test_configurations = xctestrun['TestConfigurations']
          test_configurations.each do |configuration|
            configuration['TestTargets'].each do |test_target|
              test_target['TestableName'] = test_target['BlueprintName']
              test_targets << test_target
            end
          end
        end

        tests = Hash.new([])
        test_targets.each do |xctestrun_config|
          testable_name = xctestrun_config['TestableName']
          xctest_path = xctest_bundle_path(xctestrun_rootpath, xctestrun_config)
          test_identifiers = []
          if xctestrun_config.key?('OnlyTestIdentifiers')
            test_identifiers = xctestrun_config['OnlyTestIdentifiers']
            UI.verbose("Identifiers after adding onlytest tests: #{test_identifiers.join("\n\t")}")
          else
            test_identifiers = XCTestList.tests(xctest_path, swift_test_prefix: swift_test_prefix)
            UI.verbose("Found the following tests: #{test_identifiers.join("\n\t")}")
          end
          if xctestrun_config.key?('SkipTestIdentifiers')
            test_identifiers = subtract_skipped_tests_from_test_identifiers(
              test_identifiers,
              xctestrun_config['SkipTestIdentifiers']
            )
            UI.verbose("Identifiers after removing skipped tests: #{test_identifiers.join("\n\t")}")
          end
          if test_identifiers.empty? && !invocation_based_tests
            UI.error("No tests found in '#{xctest_path}'!")
            UI.important("Is the Build Setting, `ENABLE_TESTABILITY` enabled for the test target #{testable_name}?")
            UI.message("If your Swift test method names use a prefix other than `test`, consider setting `:swift_test_prefix`.")
          end
          tests[testable_name] = test_identifiers.map do |test_identifier|
            "#{testable_name}/#{test_identifier}"
          end
        end
        tests
      end

      def self.subtract_skipped_tests_from_test_identifiers(test_identifiers, skipped_test_identifiers)
        skipped_tests_identifiers = []
        skipped_testsuites = []
        skipped_test_identifiers.each do |skipped_test|
          if skipped_test.split('/').size > 1
            skipped_tests_identifiers << skipped_test
          else
            skipped_testsuites << skipped_test
          end
        end
        skipped_testsuites.each do |skipped_testsuite|
          derived_skipped_tests = test_identifiers.select do |test_identifier|
            test_identifier.start_with?(skipped_testsuite)
          end
          skipped_tests_identifiers.concat(derived_skipped_tests)
        end

        UI.verbose("Removing skipped tests: #{skipped_tests_identifiers.join("\n\t")}")
        test_identifiers.reject { |test_identifier| skipped_tests_identifiers.include?(test_identifier) }
      end

      def self.xctest_bundle_path(xctestrun_rootpath, xctestrun_config)
        xctest_host_path = xctestrun_config['TestHostPath'].sub('__TESTROOT__', xctestrun_rootpath)
        xctestrun_config['TestBundlePath'].sub('__TESTHOST__', xctest_host_path).sub('__TESTROOT__', xctestrun_rootpath)
      end

      def self.ignoredTestables
        return ['__xctestrun_metadata__']
      end

      #####################################################
      # @!group Documentation
      #####################################################

      # :nocov:
      def self.description
        "️️☑️ Retrieves all of the tests from xctest bundles referenced by the xctestrun file"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :xctestrun,
            env_name: "FL_SUPPRESS_TESTS_FROM_XCTESTRUN_FILE",
            description: "The xctestrun file to use to find where the xctest bundle file is for test retrieval",
            verify_block: proc do |path|
              UI.user_error!("Error: cannot find the xctestrun file '#{path}'") unless File.exist?(path)
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :invocation_based_tests,
            description: "Set to true If your test suit have invocation based tests like Kiwi",
            type: Boolean,
            is_string: false,
            default_value: false,
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :swift_test_prefix,
            description: "The prefix used to find test methods. In standard XCTests, this is `test`. If you are using Quick with Swift, set this to `spec`",
            default_value: "test",
            optional: true,
            verify_block: proc do |swift_test_prefix|
              UI.user_error!("Error: swift_test_prefix must be non-nil and non-empty") if swift_test_prefix.nil? || swift_test_prefix.empty?
            end
          )
        ]
      end

      def self.return_value
        "A Hash of testable => tests, where testable is the name of the test target and tests is an array of test identifiers"
      end

      def self.example_code
        [
          "
          require 'fastlane/actions/scan'

          lane :split_tests do
            scan(
              build_for_testing: true,
              workspace: File.absolute_path('../AtomicBoy/AtomicBoy.xcworkspace'),
              scheme: 'AtomicBoy'
            )
            derived_data_path = Scan.config[:derived_data_path]
            xctestrun_file = Dir.glob(\"\#{derived_data_path}/Build/Products/*.xctestrun\").first
            tests = tests_from_xctestrun(xctestrun: xctestrun_file).values.flatten.shuffle
            slice_size = (tests.size/4.0).ceil
            tests.each_slice(slice_size).each_with_index do |inner_array, index|
              File.write(\"test_output/batch\#{index}.txt\", inner_array.join(','))
            end
          end

          lane :run_split_tests do |options|
            batch_file = File.join('test_output', \"batch\#{options[:batch_index]}.txt\")
            only_testing = File.read(batch_file).split(',')
            multi_scan(
              workspace: File.absolute_path('../AtomicBoy/AtomicBoy.xcworkspace'),
              scheme: 'AtomicBoy',
              try_count: 3,
              fail_build: false,
              only_testing: only_testing
            )
          end
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
      # :nocov:
    end
  end
end
