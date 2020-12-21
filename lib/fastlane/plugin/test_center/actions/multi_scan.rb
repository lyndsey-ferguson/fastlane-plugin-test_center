module Fastlane
  module Actions
    require 'fastlane_core/ui/errors/fastlane_common_error'
    require 'fastlane/actions/scan'
    require 'shellwords'
    require 'xctest_list'
    require 'plist'

    require_relative '../helper/multi_scan_manager'
    require_relative '../helper/scan_helper'

    ScanHelper = ::TestCenter::Helper::ScanHelper

    class MultiScanAction < Action
      def self.run(params)
        update_interdependent_params(params)
        strip_leading_and_trailing_whitespace_from_output_types(params)

        warn_of_xcode11_result_bundle_incompatability(params)
        warn_of_parallelism_with_circle_ci(params)

        print_multi_scan_parameters(params)
        force_quit_simulator_processes if params[:quit_simulators]

        prepare_for_testing(params.values)
        
        tests_passed = true
        summary = {}
        if params[:build_for_testing]
          summary = build_summary
        else
          coerce_destination_to_array(params)
          platform = :mac
          platform = :ios_simulator if Scan.config[:destination].any? { |d| d.include?('platform=iOS Simulator') }

          runner_options = params.values.merge(platform: platform)
          runner = ::TestCenter::Helper::MultiScanManager::Runner.new(runner_options)
          tests_passed = runner.run

          summary = run_summary(params, tests_passed)
        end

        print_run_summary(summary)

        if params[:fail_build] && !tests_passed
          raise UI.test_failure!('Tests have failed')
        end
        summary
      end

      def self.update_interdependent_params(params)
        params[:quit_simulators] = params._values[:force_quit_simulator] if params._values[:force_quit_simulator]
        if params[:try_count] < 1
          UI.important('multi_scan will not test any if :try_count < 0, setting to 1')
          params[:try_count] = 1
        end
      end

      def self.warn_of_parallelism_with_circle_ci(params)
        if params[:parallel_testrun_count] > 1 && Helper.is_circle_ci?
          UI.important("Warning: problems have occurreed when running parallel simulators on Circle CI.")
          UI.message("  See https://github.com/lyndsey-ferguson/fastlane-plugin-test_center/issues/179")
        end
      end

      def self.strip_leading_and_trailing_whitespace_from_output_types(params)
        if params[:output_types]
          params[:output_types] = params[:output_types].split(',').map(&:strip).join(',')
        end
        if params[:output_files]
          params[:output_files] = params[:output_files].split(',').map(&:strip).join(',')
        end
      end

      def self.warn_of_xcode11_result_bundle_incompatability(params)
        if FastlaneCore::Helper.xcode_at_least?('11.0.0')
          if params[:result_bundle]
            UI.important('As of Xcode 11, test_result bundles created in the output directory are actually symbolic links to an xcresult bundle')
          end
        elsif params[:output_types]&.include?('xcresult')
          UI.important("The 'xcresult' :output_type is only supported for Xcode 11 and greater. You are using #{FastlaneCore::Helper.xcode_version}.")
        end
      end

      def self.coerce_destination_to_array(params)
        destination = params[:destination] || Scan.config[:destination] || []
        unless destination.kind_of?(Array)
          params[:destination] = Scan.config[:destination] = [destination]
        end
      end

      def self.print_multi_scan_parameters(params)
        return if Helper.test?
        # :nocov:
        scan_keys = Fastlane::Actions::ScanAction.available_options.map(&:key)
        FastlaneCore::PrintTable.print_values(
          config: params._values.reject { |k, _| scan_keys.include?(k) },
          title: "Summary for multi_scan (test_center v#{Fastlane::TestCenter::VERSION})"
        )
        # :nocov:
      end

      def self.print_run_summary(summary)
        return if Helper.test?

        # :nocov:
        FastlaneCore::PrintTable.print_values(
          config: summary,
          title: "multi_scan results"
        )
        # :nocov:
      end

      def self.build_summary
        {
          result: true,
          total_tests: 0,
          passing_testcount: 0,
          failed_testcount: 0,
          total_retry_count: 0
        }
      end

      def self.run_summary(scan_options, tests_passed)
        scan_options = scan_options.clone

        if scan_options[:result_bundle]
          updated_output_types, updated_output_files = ::TestCenter::Helper::ReportNameHelper.ensure_output_includes_xcresult(
            scan_options[:output_types],
            scan_options[:output_files]
          )
          scan_options[:output_types] = updated_output_types
          scan_options[:output_files] = updated_output_files
        end
        reportnamer = ::TestCenter::Helper::ReportNameHelper.new(
          scan_options[:output_types],
          scan_options[:output_files],
          scan_options[:custom_report_file_name]
        )
        passing_testcount = 0
        failed_tests = []
        failure_details = {}
        report_files = Dir.glob("#{scan_options[:output_directory]}/**/#{reportnamer.junit_fileglob}").map do |relative_filepath|
          File.absolute_path(relative_filepath)
        end
        retry_total_count = 0
        report_files.each do |report_file|
          junit_results = other_action.tests_from_junit(junit: report_file)
          failed_tests.concat(junit_results[:failed])
          passing_testcount += junit_results[:passing].size
          failure_details.merge!(junit_results[:failure_details])

          report = REXML::Document.new(File.new(report_file))
          retry_total_count += (report.root.attribute('retries')&.value || 1).to_i
        end

        if reportnamer.includes_html?
          report_files += Dir.glob("#{scan_options[:output_directory]}/**/#{reportnamer.html_fileglob}").map do |relative_filepath|
            File.absolute_path(relative_filepath)
          end
        end
        if reportnamer.includes_json?
          report_files += Dir.glob("#{scan_options[:output_directory]}/**/#{reportnamer.json_fileglob}").map do |relative_filepath|
            File.absolute_path(relative_filepath)
          end
        end
        if scan_options[:result_bundle]
          report_files += Dir.glob("#{scan_options[:output_directory]}/**/*.test_result").map do |relative_test_result_bundle_filepath|
            File.absolute_path(relative_test_result_bundle_filepath)
          end
        end
        if reportnamer.includes_xcresult?
          report_files += Dir.glob("#{scan_options[:output_directory]}/**/#{reportnamer.xcresult_fileglob}").map do |relative_bundlepath|
            File.absolute_path(relative_bundlepath)
          end
        end
        {
          result: tests_passed,
          total_tests: passing_testcount + failed_tests.size,
          passing_testcount: passing_testcount,
          failed_testcount: failed_tests.size,
          failed_tests: failed_tests,
          failure_details: failure_details,
          total_retry_count: retry_total_count,
          report_files: report_files
        }
      end

      def self.prepare_for_testing(scan_options)
        reset_scan_config_to_defaults
        use_scanfile_to_override_settings(scan_options)
        turn_off_concurrent_workers(scan_options)
        UI.important("Turning off :skip_build as it doesn't do anything with multi_scan") if scan_options[:skip_build]
        if scan_options[:disable_xcpretty]
          UI.important("Turning off :disable_xcpretty as xcpretty is needed to generate junit reports for retrying failed tests")
        end
        scan_options.reject! { |k,v| %i[skip_build disable_xcpretty].include?(k) }
        ScanHelper.remove_preexisting_simulator_logs(scan_options)
        if scan_options[:test_without_building]
          UI.verbose("Preparing Scan config options for multi_scan testing")
          prepare_scan_config(scan_options)
        else
          UI.verbose("Building the project in preparation for multi_scan testing")
          build_for_testing(scan_options)
        end
      end

      def self.turn_off_concurrent_workers(scan_options)
        if Gem::Version.new(Fastlane::VERSION) >= Gem::Version.new('2.142.0')
          scan_options.delete(:concurrent_workers) if scan_options[:concurrent_workers].to_i > 0
        end
      end

      def self.reset_scan_config_to_defaults
        return unless Scan.config

        defaults = Hash[Fastlane::Actions::ScanAction.available_options.map { |i| [i.key, i.default_value] }]
        FastlaneCore::UI.verbose("MultiScanAction resetting Scan config to defaults")
        defaults.delete(:destination)

        Scan.config._values.each do |k,v|
          Scan.config.set(k, defaults[k]) if defaults.key?(k)
        end
      end

      def self.use_scanfile_to_override_settings(scan_options)
        overridden_options = ScanHelper.options_from_configuration_file(
          ScanHelper.scan_options_from_multi_scan_options(scan_options)
        )

        unless overridden_options.empty?
          FastlaneCore::UI.important("Scanfile found: overriding multi_scan options with it's values.")
          overridden_options.each do |k,v|
            scan_options[k] = v
          end
        end
      end

      def self.prepare_scan_config(scan_options)
        Scan.config ||= FastlaneCore::Configuration.create(
          Fastlane::Actions::ScanAction.available_options,
          ScanHelper.scan_options_from_multi_scan_options(scan_options)
        )
      end

      def self.build_for_testing(scan_options)
        values = prepare_scan_options_for_build_for_testing(scan_options)
        ScanHelper.print_scan_parameters(values)

        remove_preexisting_xctestrun_files
        Scan::Runner.new.run
        update_xctestrun_after_build(scan_options)
        remove_build_report_files

        Scan.config._values.delete(:build_for_testing)
        scan_options[:derived_data_path] = Scan.config[:derived_data_path]
      end

      def self.remove_xcresult_from_build_options(build_options)
        # convert the :output_types comma separated string of types into an array with no whitespace
        output_types = build_options[:output_types].to_s.split(',').map(&:strip)
        xcresult_index = output_types.index('xcresult')

        unless xcresult_index.nil?
          output_types.delete_at(xcresult_index)
          # set :output_types value to comma separated string of remaining output types
          build_options[:output_types] = output_types.join(',')

          if build_options[:output_files] # not always set
            output_files = build_options[:output_files].split(',').map(&:strip)
            output_files.delete_at(xcresult_index)

            build_options[:output_files] = output_files.join(',')
          end
        end
      end

      def self.prepare_scan_options_for_build_for_testing(scan_options)
        build_options = scan_options.merge(build_for_testing: true).reject { |k| %i[test_without_building testplan include_simulator_logs].include?(k) }
        remove_xcresult_from_build_options(build_options)
        Scan.config = FastlaneCore::Configuration.create(
          Fastlane::Actions::ScanAction.available_options,
          ScanHelper.scan_options_from_multi_scan_options(build_options).merge(include_simulator_logs: false)
        )
        values = Scan.config.values(ask: false)
        values[:xcode_path] = File.expand_path("../..", FastlaneCore::Helper.xcode_path)
        Scan.config._values.delete(:result_bundle)
        values
      end

      def self.update_xctestrun_after_build(scan_options)
        glob_pattern = "#{Scan.config[:derived_data_path]}/Build/Products/*.xctestrun"
        if scan_options[:testplan]
          glob_pattern = "#{Scan.config[:derived_data_path]}/Build/Products/*_#{scan_options[:testplan]}_*.xctestrun"
        end
        xctestrun_files = Dir.glob(glob_pattern)
        UI.verbose("After building, found xctestrun files #{xctestrun_files} (choosing 1st)")
        scan_options[:xctestrun] = xctestrun_files.first
      end

      def self.remove_preexisting_xctestrun_files
        xctestrun_files = Dir.glob("#{Scan.config[:derived_data_path]}/Build/Products/*.xctestrun")
        UI.verbose("Before building, removing pre-existing xctestrun files: #{xctestrun_files}")
        FileUtils.rm_rf(xctestrun_files)
      end

      def self.remove_build_report_files
        # When Scan builds, it generates empty report files. Trying to collate
        # subsequent, valid, report files with the empty report file will fail
        # because there is no shared XML elements
        report_options = Scan::XCPrettyReporterOptionsGenerator.generate_from_scan_config
        output_files = report_options.instance_variable_get(:@output_files)
        output_directory = report_options.instance_variable_get(:@output_directory)

        UI.verbose("Removing report files generated by the build")
        output_files.each do |output_file|
          report_file = File.join(output_directory, output_file)
          UI.verbose("  #{report_file}")
          FileUtils.rm_f(report_file)
        end
      end

      def self.force_quit_simulator_processes
        # Silently execute and kill, verbose flags will show this command occurring
        Fastlane::Actions.sh("killall Simulator &> /dev/null || true", log: false)
      end

      #####################################################
      # @!group Documentation
      #####################################################

      # :nocov:
      def self.description
        "♻️ Uses scan to run Xcode tests a given number of times, with the option of batching and/or parallelizing them, only re-testing failing tests."
      end

      def self.details
        "Use this action to run your tests if you have fragile tests that fail " \
        "sporadically, if you have a huge number of tests that should be " \
        "batched, or have multiple test targets and need meaningful junit reports."
      end

      def self.return_value
        "Returns a Hash with the following value-key pairs:\n" \
        "- result: true if the final result of running the tests resulted in " \
        "passed tests. false if there was one or more tests that failed, even " \
        "after retrying them :try_count times.\n" \
        "- total_tests: the total number of tests visited.\n" \
        "- passing_testcount: the number of tests that passed.\n" \
        "- failed_testcount: the number of tests that failed, even after retrying them.\n" \
        "- failed_tests: an array of the test identifers that failed.\n" \
        "- total_retry_count: the total number of times a test 'run' was retried.\n" \
        "- report_files: the list of junit report files generated by multi_scan."
      end

      def self.scan_options
        # multi_scan has its own enhanced version of `output_types` and we want to provide
        # the help and validation for that new version.
        ScanAction.available_options.reject { |config| %i[output_types].include?(config.key) }
      end

      def self.available_options
        scan_options + [
          FastlaneCore::ConfigItem.new(
            key: :try_count,
            env_name: "FL_MULTI_SCAN_TRY_COUNT",
            description: "The number of times to retry running tests via scan",
            type: Integer,
            is_string: false,
            default_value: 1
          ),
          FastlaneCore::ConfigItem.new(
            key: :batch_count,
            env_name: "FL_MULTI_SCAN_BATCH_COUNT",
            description: "The number of test batches to run through scan. Can be combined with :try_count",
            type: Integer,
            is_string: false,
            default_value: 1,
            optional: true,
            verify_block: proc do |count|
              UI.user_error!("Error: Batch counts must be greater than zero") unless count > 0
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :batches,
            env_name: "FL_MULTI_SCAN_BATCHES",
            description: "The explicit batches (an Array of Arrays of test identifiers) to run either serially, or each batch on a simulator in parallel if :parallel_testrun_count is given",
            type: Array,
            optional: true,
            conflicting_options: [:batch_count]
          ),
          FastlaneCore::ConfigItem.new(
            key: :retry_test_runner_failures,
            description: "Set to true If you want to treat build failures during testing, like 'Test runner exited before starting test execution', as 'all tests failed'",
            type: Boolean,
            default_value: false,
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :invocation_based_tests,
            description: "Set to true If your test suit have invocation based tests like Kiwi",
            type: Boolean,
            is_string: false,
            default_value: false,
            optional: true,
            conflicting_options: %i[batch_count batches],
            conflict_block: proc do |value|
              UI.user_error!(
                "Error: Can't use 'invocation_based_tests' and 'batch_count' options in one run, "\
                "because the number of tests is unknown")
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :swift_test_prefix,
            description: "The prefix used to find test methods. In standard XCTests, this is `test`. If you are using Quick with Swift, set this to `spec`",
            default_value: "test",
            optional: true,
            verify_block: proc do |swift_test_prefix|
              UI.user_error!("Error: swift_test_prefix must be non-nil and non-empty") if swift_test_prefix.nil? || swift_test_prefix.empty?
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :quit_simulators,
            env_name: "FL_MULTI_SCAN_QUIT_SIMULATORS",
            description: "If the simulators need to be killed before running the tests",
            type: Boolean,
            is_string: false,
            default_value: true,
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :output_types,
            short_option: "-f",
            env_name: "SCAN_OUTPUT_TYPES",
            description: "Comma separated list of the output types (e.g. html, junit, json, json-compilation-database, xcresult)",
            default_value: "html,junit"
          ),
          FastlaneCore::ConfigItem.new(
            key: :collate_reports,
            description: "Whether or not to collate the reports generated by multiple retries, batches, and parallel test runs",
            default_value: true,
            is_string: false
          ),
          FastlaneCore::ConfigItem.new(
            key: :parallel_testrun_count,
            description: 'Run simulators each batch of tests and/or each test target in parallel on its own Simulator',
            optional: true,
            is_string: false,
            default_value: 1,
            verify_block: proc do |count|
              UI.user_error!("Error: :parallel_testrun_count must be greater than zero") unless count > 0
              UI.important("Warning: the CoreSimulatorService may fail to connect to simulators if :parallel_testrun_count is greater than 6") if count > 6
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :pre_delete_cloned_simulators,
            description: 'Delete left over cloned simulators before running a parallel testrun',
            optional: true,
            is_string: false,
            default_value: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :override_scan_options_block,
            description: 'A block invoked with a Hash of the scan options that will be used when test run is about to start. This allows your code to modify the arguments that will be sent to scan',
            optional: true,
            is_string: false,
            default_value: nil,
            type: Proc
          ),
          FastlaneCore::ConfigItem.new(
            key: :reuse_simulators_for_parallel_testruns,
            description: 'Find simulators (or clone new ones) that match the requested device for the parallel test runs. This option sets :pre_delete_cloned_simulators to false',
            optional: true,
            is_string: false,
            type: Boolean,
            default_value: false
          ),
          FastlaneCore::ConfigItem.new(
            key: :testrun_completed_block,
            description: 'A block invoked each time a test run completes. When combined with :parallel_testrun_count, will be called separately in each child process. Return a Hash with :continue set to false to stop retrying tests, or :only_testing to change which tests will be run in the next try',
            optional: true,
            is_string: false,
            default_value: nil,
            type: Proc
          ),
          FastlaneCore::ConfigItem.new(
            key: :simulator_started_callback,
            description: 'A block invoked after the iOS simulators have started',
            optional: true,
            is_string: false,
            default_value: nil,
            type: Proc
          )
        ]
      end

      def self.example_code
        [
          "
          UI.important(
            'example: ' \\
            'split the tests into 4 batches and run each batch of tests in ' \\
            'parallel up to 3 times if tests fail. Abort the testing early ' \\
            'if there are too many failing tests by passing in a ' \\
            ':testrun_completed_block that is called by :multi_scan ' \\
            'after each run of tests.'
          )
          test_run_block = lambda do |testrun_info|
            failed_test_count = testrun_info[:failed].size
            passed_test_count = testrun_info[:passing].size
            try_attempt = testrun_info[:try_count]
            batch = testrun_info[:batch]

            # UI.abort_with_message!('You could conditionally abort')
            UI.message(\"\\\u1F60A everything is fine, let's continue try \#{try_attempt + 1} for batch \#{batch}\")
            {
              continue: true,
              only_testing: ['AtomicBoyUITests/AtomicBoyUITests/testExample17']
            }
          end

          sim_callback = lambda do |simulator_device_udid|
            puts \"Start streaming system log for device \#{simulator_device_udid}\"
          end

          multi_scan(
            project: File.absolute_path('../AtomicBoy/AtomicBoy.xcodeproj'),
            scheme: 'AtomicBoy',
            try_count: 3,
            batch_count: 4,
            fail_build: false,
            parallel_testrun_count: 4,
            testrun_completed_block: test_run_block,
            simulator_started_callback: sim_callback
          )
          ",
          "
          UI.important(
            'example: ' \\
            'multi_scan also works with json.'
          )
          multi_scan(
            workspace: File.absolute_path('../AtomicBoy/AtomicBoy.xcworkspace'),
            scheme: 'AtomicBoy',
            try_count: 3,
            output_types: 'json',
            output_files: 'report.json',
            fail_build: false
          )
          ",
          "
          UI.header('batches feature')
          multi_scan(
            workspace: File.absolute_path('../AtomicBoy/AtomicBoy.xcworkspace'),
            scheme: 'AtomicBoy',
            try_count: 3,
            fail_build: false,
            batches: [
              [
                'AtomicBoyUITests/AtomicBoyUITests/testExample5',
                'AtomicBoyUITests/AtomicBoyUITests/testExample10',
                'AtomicBoyUITests/AtomicBoyUITests/testExample15'
              ],
              [
                'AtomicBoyUITests/AtomicBoyUITests/testExample6',
                'AtomicBoyUITests/AtomicBoyUITests/testExample12',
                'AtomicBoyUITests/AtomicBoyUITests/testExample18'
              ]
            ]
          )
          "
        ]
      end

      def self.integration_tests
        [
          "
          UI.header('Basic test')
          multi_scan(
            workspace: File.absolute_path('../AtomicBoy/AtomicBoy.xcworkspace'),
            scheme: 'AtomicBoy',
            fail_build: false,
            try_count: 2,
            disable_xcpretty: true
          )
          ",
          "
          UI.header('Basic test with 1 specific test')
          multi_scan(
            workspace: File.absolute_path('../AtomicBoy/AtomicBoy.xcworkspace'),
            scheme: 'AtomicBoy',
            fail_build: false,
            try_count: 2,
            only_testing: ['AtomicBoyUITests/AtomicBoyUITests/testExample']
          )
          ",
          "
          UI.header('Basic test with test target expansion')
          multi_scan(
            workspace: File.absolute_path('../AtomicBoy/AtomicBoy.xcworkspace'),
            scheme: 'AtomicBoy',
            fail_build: false,
            try_count: 2,
            only_testing: ['AtomicBoyUITests', 'AtomicBoyTests']
          )
          ",
          "
          UI.header('Parallel test run')
          multi_scan(
            workspace: File.absolute_path('../AtomicBoy/AtomicBoy.xcworkspace'),
            scheme: 'AtomicBoy',
            fail_build: false,
            try_count: 2,
            parallel_testrun_count: 2
          )
          ",
          "
          UI.header('Parallel test run with fewer tests than parallel test runs')
          multi_scan(
            workspace: File.absolute_path('../AtomicBoy/AtomicBoy.xcworkspace'),
            scheme: 'AtomicBoy',
            fail_build: false,
            try_count: 2,
            parallel_testrun_count: 4,
            only_testing: ['AtomicBoyUITests/AtomicBoyUITests/testExample']
          )
          ",
          "
          UI.header('Basic test with batch count')
          multi_scan(
            workspace: File.absolute_path('../AtomicBoy/AtomicBoy.xcworkspace'),
            scheme: 'AtomicBoy',
            fail_build: false,
            try_count: 2,
            batch_count: 2
          )
          ",
          "
          UI.header('Basic test with batches')
          multi_scan(
            workspace: File.absolute_path('../AtomicBoy/AtomicBoy.xcworkspace'),
            scheme: 'AtomicBoy',
            fail_build: false,
            try_count: 2,
            batches: [
              ['AtomicBoyUITests/AtomicBoyUITests/testExample', 'AtomicBoyUITests/AtomicBoyUITests/testExample2'],
              ['AtomicBoyUITests/AtomicBoyUITests/testExample3', 'AtomicBoyUITests/AtomicBoyUITests/testExample4']
            ],
            parallel_testrun_count: 2
          )
          ",
          "
          UI.header('Basic test with xcresult')
          multi_scan(
            workspace: File.absolute_path('../AtomicBoy/AtomicBoy.xcworkspace'),
            scheme: 'AtomicBoy',
            output_types: 'xcresult',
            output_files: 'result.xcresult',
            collate_reports: false,
            fail_build: false,
            try_count: 2,
            batch_count: 2
          )
          "
        ]
      end

      def self.integration_tests
        [
          "
          UI.header('Basic test')
          multi_scan(
            workspace: File.absolute_path('../AtomicBoy/AtomicBoy.xcworkspace'),
            scheme: 'AtomicBoy',
            fail_build: false,
            try_count: 2,
            disable_xcpretty: true
          )
          ",
          "
          UI.header('Basic test with 1 specific test')
          multi_scan(
            workspace: File.absolute_path('../AtomicBoy/AtomicBoy.xcworkspace'),
            scheme: 'AtomicBoy',
            fail_build: false,
            try_count: 2,
            only_testing: ['AtomicBoyUITests/AtomicBoyUITests/testExample']
          )
          ",
          "
          UI.header('Basic test with test target expansion')
          multi_scan(
            workspace: File.absolute_path('../AtomicBoy/AtomicBoy.xcworkspace'),
            scheme: 'AtomicBoy',
            fail_build: false,
            try_count: 2,
            only_testing: ['AtomicBoyUITests', 'AtomicBoyTests']
          )
          ",
          "
          UI.header('Parallel test run')
          multi_scan(
            workspace: File.absolute_path('../AtomicBoy/AtomicBoy.xcworkspace'),
            scheme: 'AtomicBoy',
            fail_build: false,
            try_count: 2,
            parallel_testrun_count: 2
          )
          ",
          "
          UI.header('Parallel test run with fewer tests than parallel test runs')
          multi_scan(
            workspace: File.absolute_path('../AtomicBoy/AtomicBoy.xcworkspace'),
            scheme: 'AtomicBoy',
            fail_build: false,
            try_count: 2,
            parallel_testrun_count: 4,
            only_testing: ['AtomicBoyUITests/AtomicBoyUITests/testExample']
          )
          ",
          "
          UI.header('Basic test with batches')
          multi_scan(
            workspace: File.absolute_path('../AtomicBoy/AtomicBoy.xcworkspace'),
            scheme: 'AtomicBoy',
            fail_build: false,
            try_count: 2,
            batch_count: 2
          )
          ",
          "
          UI.header('Basic test with xcresult')
          multi_scan(
            workspace: File.absolute_path('../AtomicBoy/AtomicBoy.xcworkspace'),
            scheme: 'AtomicBoy',
            output_types: 'xcresult',
            output_files: 'result.xcresult',
            collate_reports: false,
            fail_build: false,
            try_count: 2,
            batch_count: 2
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
