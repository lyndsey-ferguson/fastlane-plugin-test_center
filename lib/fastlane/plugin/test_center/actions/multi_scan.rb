module Fastlane
  module Actions
    require 'fastlane_core/ui/errors/fastlane_common_error'
    require 'fastlane/actions/scan'
    require 'shellwords'
    require 'xctest_list'
    require 'plist'

    class MultiScanAction < Action
      def self.run(params)
        unless Helper.test?
          FastlaneCore::PrintTable.print_values(
            config: params._values.select { |k, _| %i[try_count batch_count fail_build quit_simulators].include?(k) },
            title: "Summary for multi_scan (test_center v#{Fastlane::TestCenter::VERSION})"
          )
        end
        unless params[:test_without_building] || params[:skip_build]
          build_for_testing(
            params._values
          )
        end
        retrying_scan = ::TestCenter::Helper::RetryingScan::Runner.new(params.values)
        tests_passed = retrying_scan.scan
        if params[:fail_build] && !tests_passed
          raise UI.test_failure!('Tests have failed')
        end

        summary = run_summary(params, tests_passed, retrying_scan.retry_total_count)
        unless Helper.test?
          FastlaneCore::PrintTable.print_values(
            config: summary,
            title: "multi_scan results"
          )
        end
        if params[:fail_build] && !tests_passed
          raise UI.test_failure!('Tests have failed')
        end
        summary
      end

      def self.run_summary(scan_options, tests_passed, retry_total_count)
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
        report_files.each do |report_file|
          junit_results = other_action.tests_from_junit(junit: report_file)
          failed_tests.concat(junit_results[:failed])
          passing_testcount += junit_results[:passing].size
          failure_details.merge!(junit_results[:failure_details])
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

      def self.build_for_testing(scan_options)
        options_to_remove = %i[
          try_count
          batch_count
          output_files
          parallelize
          quit_simulators
          testrun_completed_block
          test_without_building
          output_types
        ]
        config = FastlaneCore::Configuration.create(
          Fastlane::Actions::ScanAction.available_options,
          scan_options.merge(build_for_testing: true).reject { |k, _| options_to_remove.include?(k) }
        )
        Fastlane::Actions::ScanAction.run(config)

        scan_options.merge!(
          test_without_building: true,
          derived_data_path: Scan.config[:derived_data_path]
        ).delete(:build_for_testing)
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Uses scan to run Xcode tests a given number of times, with the option " \
        "of batching them, only re-testing failing tests."
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
        ScanAction.available_options.reject { |config| config.key == :output_types }
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
            key: :quit_simulators,
            env_name: "FL_MULTI_SCAN_QUIT_SIMULATORS",
            description: "If the simulators need to be killed before run the tests",
            type: Boolean,
            is_string: false,
            default_value: true,
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :output_types,
            short_option: "-f",
            env_name: "SCAN_OUTPUT_TYPES",
            description: "Comma separated list of the output types (e.g. html, junit, json, json-compilation-database)",
            default_value: "html,junit"
          ),
          FastlaneCore::ConfigItem.new(
            key: :parallelize,
            description: 'Run each batch of tests and/or each test target in parallel on its own Simulator',
            optional: true,
            is_string: false,
            default_value: false
          ),
          FastlaneCore::ConfigItem.new(
            key: :testrun_completed_block,
            description: 'A block invoked each time a test run completes',
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
            'run tests for a scheme that has two test targets, re-trying up to 2 times if ' \\
            'tests fail. Turn off the default behavior of failing the build if, at the ' \\
            'end of the action, there were 1 or more failing tests.'
          )
          summary = multi_scan(
            project: File.absolute_path('../AtomicBoy/AtomicBoy.xcodeproj'),
            scheme: 'AtomicBoy',
            try_count: 3,
            fail_build: false,
            output_files: 'report.html',
            output_types: 'html'
          )
          UI.success(\"multi_scan passed? \#{summary[:result]}\")
          ",
          "
          UI.important(
            'example: ' \\
            'split the tests into 2 batches and run each batch of tests up to 3 ' \\
            'times if tests fail. Do not fail the build.'
          )
          multi_scan(
            project: File.absolute_path('../AtomicBoy/AtomicBoy.xcodeproj'),
            scheme: 'AtomicBoy',
            try_count: 3,
            batch_count: 2,
            fail_build: false
          )
          ",
          "
          UI.important(
            'example: ' \\
            'split the tests into 2 batches and run each batch of tests up to 3 ' \\
            'times if tests fail. Abort the testing early if there are too many ' \\
            'failing tests by passing in a :testrun_completed_block that is called ' \\
            'by :multi_scan after each run of tests.'
          )
          test_run_block = lambda do |testrun_info|
            failed_test_count = testrun_info[:failed].size
            passed_test_count = testrun_info[:passing].size
            try_attempt = testrun_info[:try_count]
            batch = testrun_info[:batch]

            # UI.abort_with_message!('You could conditionally abort')
            UI.message(\"\\\u1F60A everything is fine, let's continue try \#{try_attempt + 1} for batch \#{batch}\")
          end

          multi_scan(
            project: File.absolute_path('../AtomicBoy/AtomicBoy.xcodeproj'),
            scheme: 'AtomicBoy',
            try_count: 3,
            batch_count: 2,
            fail_build: false,
            testrun_completed_block: test_run_block
          )
          ",
          "
          UI.important(
            'example: ' \\
            'use the :workspace parameter instead of the :project parameter to find, ' \\
            'build, and test the iOS app.'
          )
          begin
            multi_scan(
              workspace: File.absolute_path('../AtomicBoy/AtomicBoy.xcworkspace'),
              scheme: 'AtomicBoy',
              try_count: 3
            )
          rescue # anything
            UI.error('Found real failing tests!')
          end
          ",
          "
          UI.important(
            'example: ' \\
            'use the :workspace parameter instead of the :project parameter to find, ' \\
            'build, and test the iOS app. Use the :skip_build parameter to not rebuild.'
          )
          multi_scan(
            workspace: File.absolute_path('../AtomicBoy/AtomicBoy.xcworkspace'),
            scheme: 'AtomicBoy',
            skip_build: true,
            clean: true,
            try_count: 3,
            result_bundle: true,
            fail_build: false
          )
          ",
          "
          UI.important(
            'example: ' \\
            'multi_scan also works with just one test target in the Scheme.'
          )
          multi_scan(
            project: File.absolute_path('../AtomicBoy/AtomicBoy.xcodeproj'),
            scheme: 'Professor',
            try_count: 3,
            output_files: 'atomic_report.xml',
            output_types: 'junit',
            fail_build: false
          )
          ",
          "
          UI.important(
            'example: ' \\
            'multi_scan also can also run just the tests passed in the ' \\
            ':only_testing option.'
          )
          multi_scan(
            workspace: File.absolute_path('../AtomicBoy/AtomicBoy.xcworkspace'),
            scheme: 'AtomicBoy',
            try_count: 3,
            code_coverage: true,
            only_testing: ['AtomicBoyTests'],
            fail_build: false
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
    end
  end
end
