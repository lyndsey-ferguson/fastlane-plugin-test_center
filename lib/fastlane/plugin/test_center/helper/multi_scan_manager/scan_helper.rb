module TestCenter
  module Helper
    module MultiScanManager
      require 'pry-byebug'

      class ScanHelper

        def initialize(scan_options, parallelize = false)
          @scan_options = scan_options
          @parallelize = parallelize
        end
        
        def before_all
          if @parallelize
            setup_scan_config
            FastlaneCore::DeviceManager.simulators('iOS').each do |simulator|
              simulator.delete if /-batchclone-/ =~ simulator.name
            end
          end
        end

        def setup_scan_config
          unless ::Scan.config&.fetch(:destination)
            ::Scan.config = FastlaneCore::Configuration.create(
              Fastlane::Actions::ScanAction.available_options,
              @scan_options
            )
          end
        end

        def after_each(exception)
          if exception.kind_of?(FastlaneCore::Interface::FastlaneTestFailure)
          elsif exception.kind_of?(FastlaneCore::Interface::FastlaneBuildFailure)
            derived_data_path = File.expand_path(@scan_options[:derived_data_path])
            test_session_logs = Dir.glob("#{derived_data_path}/Logs/Test/*.xcresult/*_Test/Diagnostics/**/Session-*.log")
            test_session_logs.sort! { |logfile1, logfile2| File.mtime(logfile1) <=> File.mtime(logfile2) }
            test_session = File.open(test_session_logs.last)
            backwards_seek_offset = -1 * [1000, test_session.stat.size].min
            test_session.seek(backwards_seek_offset, IO::SEEK_END)
            case test_session.read
            when /Test operation failure: Test runner exited before starting test execution/
              FastlaneCore::UI.message("Test runner for simulator <udid> failed to start")
            when /Test operation failure: Lost connection to testmanagerd/
              FastlaneCore::UI.error("Test Manager Daemon unexpectedly disconnected from test runner")
              FastlaneCore::UI.important("com.apple.CoreSimulator.CoreSimulatorService may have become corrupt, consider quitting it")
              if @scan_options[:quit_core_simulator_service]
                Fastlane::Actions::RestartCoreSimulatorServiceAction.run
              else
              end
            else
              raise exception
            end
          end
        end
      end
    end
  end
end
