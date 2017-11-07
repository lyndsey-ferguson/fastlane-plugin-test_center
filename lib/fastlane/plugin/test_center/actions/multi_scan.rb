module Fastlane
  module Actions
    require 'fastlane/actions/scan'

    class MultiScanAction < Action
      def self.run(params)
        try_count = 0
        scan_options = params.values.reject { |k| k == :try_count }

        scan_options = config_with_junit_report(scan_options)

        unless scan_options[:test_without_building]
          build_for_testing(scan_options)
          scan_options.delete(:build_for_testing)
          scan_options[:test_without_building] = true
        end

        begin
          try_count += 1
          other_action.scan(scan_options)
        rescue FastlaneCore::Interface::FastlaneTestFailure => e
          UI.verbose("Scan failed with #{e}")
          report_filepath = junit_report_filepath(scan_options)
          scan_options[:only_testing] = other_action.tests_from_junit(junit: report_filepath)[:failed]
          retry if try_count < params[:try_count]
        end
      end

      def self.build_for_testing(scan_options)
        scan_options.delete(:test_without_building)
        scan_options[:build_for_testing] = true
        other_action.scan(scan_options)
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

      def self.junit_report_filepath(config)
        report_filename = config[:custom_report_file_name]
        if report_filename.nil?
          junit_index = config[:output_types].split(',').find_index('junit')
          report_filename = config[:output_files].to_s.split(',')[junit_index]
        end
        File.join(config[:output_directory], report_filename)
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "A short description with <= 80 characters of what this action does"
      end

      def self.details
        # Optional:
        # this is your chance to provide a more detailed description of this action
        "You can use this action to do cool things..."
      end

      def self.scan_options
        ScanAction.available_options.reject { |config_item| config_item.key == :output_files }
      end

      def self.available_options
        scan_options + [
          FastlaneCore::ConfigItem.new(
            key: :try_count,
            env_name: "FL_MULTI_SCAN_TRY_COUNT", # The name of the environment variable
            description: "The number of times to retry running tests via scan", # a short description of this parameter
            type: Integer,
            is_string: false,
            default_value: 1
          )
        ]
      end

      def self.output
        # Define the shared values you are going to provide
        # Example
        [
          ['MULTI_SCAN_CUSTOM_VALUE', 'A description of what this value contains']
        ]
      end

      def self.return_value
        # If your method provides a return value, you can describe here what it does
      end

      def self.authors
        # So no one will ever forget your contribution to fastlane :) You are awesome btw!
        ["Your GitHub/Twitter Name"]
      end

      def self.is_supported?(platform)
        # you can do things like
        #
        #  true
        #
        #  platform == :ios
        #
        #  [:ios, :mac].include?(platform)
        #

        platform == :ios
      end
    end
  end
end
