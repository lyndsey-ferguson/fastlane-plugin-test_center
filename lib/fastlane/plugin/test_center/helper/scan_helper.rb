
module TestCenter
  module Helper
    module ScanHelper
      def self.print_scan_parameters(params)
        return if FastlaneCore::Helper.test?
    
        # :nocov:
        FastlaneCore::PrintTable.print_values(
          config: params,
          hide_keys: [:destination, :slack_url],
          title: "Summary for scan #{Fastlane::VERSION}"
        )
        # :nocov:
      end

      def self.remove_preexisting_simulator_logs(params)
        return unless params[:include_simulator_logs]
    
        output_directory = File.absolute_path(params.fetch(:output_directory, 'test_results'))
    
        glob_pattern = "#{output_directory}/**/system_logs-*.{log,logarchive}"
        logs = Dir.glob(glob_pattern)
        FileUtils.rm_rf(logs)
      end
    
      def self.scan_options_from_multi_scan_options(params)
        valid_scan_keys = Fastlane::Actions::ScanAction.available_options.map(&:key)
        params.select { |k,v| valid_scan_keys.include?(k) }
      end
    
      def self.options_from_configuration_file(params)
        config = FastlaneCore::Configuration.create(
          Fastlane::Actions::ScanAction.available_options,
          params
        )
        config_file = config.load_configuration_file(Scan.scanfile_name, nil, true)
    
        overridden_options = config_file ? config_file.options : {}
    
        FastlaneCore::Project.detect_projects(config)
        project = FastlaneCore::Project.new(config)
        
        imported_path = File.expand_path(Scan.scanfile_name)
        Dir.chdir(File.expand_path("..", project.path)) do
          config_file = config.load_configuration_file(Scan.scanfile_name, nil, true) unless File.expand_path(Scan.scanfile_name) == imported_path
          overridden_options.merge!(config_file.options) if config_file
        end
        overridden_options
      end
    end
  end
end

