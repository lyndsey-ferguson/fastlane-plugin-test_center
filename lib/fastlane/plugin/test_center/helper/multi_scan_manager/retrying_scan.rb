module TestCenter
  module Helper
    module MultiScanManager
      class RetryingScan
        def initialize(options = {})
          @options = options
          @retrying_scan_helper = RetryingScanHelper.new(@options)
        end

        # :nocov:
        def scan_config
          Scan.config
        end

        def scan_cache
          Scan.cache
        end
        # :nocov:

        def prepare_scan_config
          # this allows multi_scan's `destination` option to be picked up by `scan`
          scan_config._values.delete(:device)
          ENV.delete('SCAN_DEVICE')
          scan_config._values.delete(:devices)
          ENV.delete('SCAN_DEVICES')
          # this prevents double -resultBundlePath args to xcodebuild
          if ReportNameHelper.includes_xcresult?(@options[:output_types])
            scan_config._values.delete(:result_bundle)
            ENV.delete('SCAN_RESULT_BUNDLE')
          end
          scan_config._values.delete(:skip_testing)
          scan_config._values.delete(:testplan)
          if scan_config.config_file_options
            scan_config.config_file_options.reject! { |k, v| %i[skip_testing testplan device devices].include?(k) }
          end
          scan_cache.clear
        end

        def update_scan_options
          valid_scan_keys = Fastlane::Actions::ScanAction.available_options.map(&:key)
          scan_options = @options.select { |k,v| valid_scan_keys.include?(k) }
                                  .merge(@retrying_scan_helper.scan_options)

          prepare_scan_config
          scan_options[:build_for_testing] = false
          scan_options.delete(:skip_testing)
          FastlaneCore::UI.verbose("retrying_scan #update_scan_options")
          scan_options.each do |k,v|
            next if v.nil?

            scan_config.set(k,v) unless v.nil?
            FastlaneCore::UI.verbose("\tSetting #{k.to_s} to #{v}")
          end
          if @options[:scan_devices_override]
            scan_device_names = @options[:scan_devices_override].map { |device| device.name }
            FastlaneCore::UI.verbose("\tSetting Scan.devices to #{scan_device_names}")
            if Scan.devices
              Scan.devices.replace(@options[:scan_devices_override])
            else
              Scan.devices = @options[:scan_devices_override]
            end
          end
        end

        # :nocov:
        def self.run(options)
          RetryingScan.new(options).run
        end
        # :nocov:

        def run
          try_count = @options[:try_count] || 1
          begin
            @retrying_scan_helper.before_testrun
            update_scan_options

            values = scan_config.values(ask: false)
            values[:xcode_path] = File.expand_path("../..", FastlaneCore::Helper.xcode_path)
            ScanHelper.print_scan_parameters(values)

            Scan::Runner.new.run
            @retrying_scan_helper.after_testrun
            true
          rescue FastlaneCore::Interface::FastlaneTestFailure => e
            @retrying_scan_helper.after_testrun(e)
            retry if @retrying_scan_helper.testrun_count < try_count
            false
          rescue FastlaneCore::Interface::FastlaneBuildFailure => e
            @retrying_scan_helper.after_testrun(e)
            retry if @retrying_scan_helper.testrun_count < try_count
            false
          end
        end
      end
    end
  end
end
