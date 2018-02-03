module Fastlane
  module Actions
    require 'fastlane/actions/scan'
    require 'shellwords'
    require 'xctest_list'
    require 'plist'

    class MultiScanAction < Action
      def self.run(params)
        unless Helper.test?
          FastlaneCore::PrintTable.print_values(
            config: params._values.select { |k, _| %i[try_count batch_count].include?(k) },
            title: "Summary for multi_scan (test_center v#{Fastlane::TestCenter::VERSION})"
          )
        end
        unless params[:test_without_building]
          build_for_testing(
            params._values
          )
        end

        smart_scanner = ::TestCenter::Helper::CorrectingScanHelper.new(params._values)
        smart_scanner.scan
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
