module Fastlane
  module Actions
    require 'fastlane/actions/scan'
    require 'shellwords'

    class MultiScanAction < Action
      def self.run(params)
        try_count = 0
        scan_options = params.values.reject { |k| k == :try_count }

        FastlaneCore::PrintTable.print_values(
          config: params._values.reject { |k, v| scan_options.key?(k) },
          title: "Summary for mult_scan (test_center v#{Fastlane::TestCenter::VERSION})"
        )

        scan_options = config_with_junit_report(scan_options)

        unless scan_options[:test_without_building]
          build_for_testing(scan_options)
          scan_options.delete(:build_for_testing)
          scan_options[:test_without_building] = true
        end

        begin
          try_count += 1
          config = FastlaneCore::Configuration.create(Fastlane::Actions::ScanAction.available_options, scan_options)
          Fastlane::Actions::ScanAction.run(config)
        rescue FastlaneCore::Interface::FastlaneTestFailure => e
          UI.verbose("Scan failed with #{e}")
          if try_count < params[:try_count]
            report_filepath = junit_report_filepath(scan_options)
            failed_tests = other_action.tests_from_junit(junit: report_filepath)[:failed]
            scan_options[:only_testing] = failed_tests.map(&:shellescape)
            increment_junit_report_filename(scan_options)
            retry
          end
        end
      end

      def self.build_for_testing(scan_options)
        scan_options.delete(:test_without_building)
        scan_options[:build_for_testing] = true
        config = FastlaneCore::Configuration.create(Fastlane::Actions::ScanAction.available_options, scan_options)
        Fastlane::Actions::ScanAction.run(config)
      end

      def self.config_has_junit_report(config)
        output_types = config.fetch(:output_types, '').to_s.split(',')
        output_filenames = config.fetch(:output_files, '').to_s.split(',')

        output_type_file_count_match = output_types.size == output_filenames.size
        output_types.include?('junit') && (output_type_file_count_match || config[:custom_report_file_name].to_s.strip.length > 0)
      end

      def self.config_with_junit_report(config)
        return config if config_has_junit_report(config)

        if config[:output_types].to_s.strip.empty? || config[:custom_report_file_name]
          config[:custom_report_file_name] ||= 'report.xml'
          config[:output_types] = 'junit'
        elsif config[:output_types].strip == 'junit' && config[:output_files].to_s.strip.empty?
          config[:custom_report_file_name] ||= 'report.xml'
        elsif !config[:output_types].split(',').include?('junit')
          config[:output_types] << ',junit'
          config[:output_files] << ',report.xml'
        elsif config[:output_files].nil?
          config[:output_files] = config[:output_types].split(',').map { |type| "report.#{type}" }.join(',')
        end
        config
      end

      def self.junit_report_filename(config)
        report_filename = config[:custom_report_file_name]
        if report_filename.nil?
          junit_index = config[:output_types].split(',').find_index('junit')
          report_filename = config[:output_files].to_s.split(',')[junit_index]
        end
        report_filename
      end

      def self.junit_report_filepath(config)
        File.absolute_path(File.join(config[:output_directory], junit_report_filename(config)))
      end

      def self.increment_junit_report_filename(config)
        new_report_number = 2
        report_filename = junit_report_filename(config)
        if /^(?<report_filename_no_suffix>.*)-(?<report_number>\d+)\.xml/ =~ report_filename
          new_report_number = report_number.to_i + 1
          report_filename = report_filename_no_suffix
        end
        new_report_filename = "#{File.basename(report_filename, '.*')}-#{new_report_number}.xml"
        if config[:custom_report_file_name]
          config[:custom_report_file_name] = new_report_filename
        else
          junit_index = config[:output_types].split(',').find_index('junit')
          output_files = config[:output_files].to_s.split(',')
          output_files[junit_index] = new_report_filename
          config[:output_files] = output_files.join(',')
        end
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
