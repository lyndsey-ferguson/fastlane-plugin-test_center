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
            config: params._values.select { |k, _| %i[try_count batch_count fail_build].include?(k) },
            title: "Summary for multi_scan (test_center v#{Fastlane::TestCenter::VERSION})"
          )
        end
        unless params[:test_without_building]
          build_for_testing(
            params._values
          )
        end

        smart_scanner = ::TestCenter::Helper::CorrectingScanHelper.new(params._values)
        tests_passed = smart_scanner.scan
        if params[:fail_build] && !tests_passed
          raise UI.test_failure!('Tests have failed')
        end
      end

      def self.build_for_testing(scan_options)
        config = FastlaneCore::Configuration.create(
          Fastlane::Actions::ScanAction.available_options,
          scan_options.merge(build_for_testing: true).reject { |k, _| %i[try_count batch_count test_without_building].include?(k) }
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
        "Uses scan to run Xcode tests a given number of times: only re-testing failing tests."
      end

      def self.details
        "Use this action to run your tests if you have fragile tests that fail sporadically."
      end

      def self.scan_options
        ScanAction.available_options
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
            key: :testrun_failed_block,
            description: 'A block invoked each time a test run fails',
            optional: true,
            is_string: false,
            default_value: nil
          )
        ]
      end

      def self.example_code
        [
          'multi_scan(
            project: File.absolute_path("../AtomicBoy/AtomicBoy.xcodeproj"),
            scheme: "Professor",
            try_count: 3,
            custom_report_file_name: "atomic_report.xml",
            output_types: "junit"
          )',
          'multi_scan(
            project: File.absolute_path("../GalaxyFamily/GalaxyFamily.xcodeproj"),
            scheme: "Everything",
            try_count: 3,
            batch_count: 2, # splits the tests into two chunks to not overload the iOS Simulator
            custom_report_file_name: "atomic_report.xml",
            output_types: "junit"
          )',
          'multi_scan(
            project: File.absolute_path("../GalaxyFamily/GalaxyFamily.xcodeproj"),
            scheme: "Everything",
            try_count: 3,
            batch_count: 8, # splits the tests into 8 chunks to not overload the iOS Simulator
            testrun_completion_block: lambda { |testrun_info|
              passed_test_count = testrun_info[:failed_count]
              failed_test_count = testrun_info[:passed_count]
              try_attempt = testrun_info[:try_attempt]
              batch = testrun_info[:batch]

              if failed_test_count > passed_test_count / 2
                return false # the return value of this block indicates whether or not to exit early
              else
                UI.message("testrun_info: #{testrun_info}")
              end

              UI.message("😊 everything is fine, let\'s continue try #{try_attempt} for batch #{batch}")
              # nil or true lets the testing continue
            }
          )'
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
