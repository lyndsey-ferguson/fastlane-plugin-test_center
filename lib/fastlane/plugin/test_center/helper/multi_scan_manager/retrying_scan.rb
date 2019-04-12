require 'pry-byebug'
module TestCenter
  module Helper
    module MultiScanManager
      class RetryingScan
        def initialize(scan_options: {})
          @scan_options = scan_options
        end

        def run
          try_count = 0
          begin
            try_count += 1
            config = FastlaneCore::Configuration.create(
              Fastlane::Actions::ScanAction.available_options,
              @scan_options.reject do |option, _|
                %i[quit_core_simulator_service].include?(option)
              end
            )
            Fastlane::Actions::ScanAction.run(config)
          rescue FastlaneCore::Interface::FastlaneTestFailure => e
            retry if try_count < 3
          rescue FastlaneCore::Interface::FastlaneBuildFailure => e
            derived_data_path = File.expand_path(@scan_options[:derived_data_path])
            test_session_logs = Dir.glob("#{derived_data_path}/Logs/Test/*.xcresult/*_Test/Diagnostics/**/Session-*.log")
            test_session_logs.sort! { |logfile1, logfile2| File.mtime(logfile1) <=> File.mtime(logfile2) }
            test_session = File.open(test_session_logs.last)
            backwards_seek_offset = -1 * [1000, test_session.stat.size].min
            test_session.seek(backwards_seek_offset, IO::SEEK_END)
            case test_session.read
            when /Test operation failure: Test runner exited before starting test execution/
              FastlaneCore::UI.message("Test runner for simulator <udid> failed to start")
              retry if try_count < 3
            when /Test operation failure: Lost connection to testmanagerd/
              FastlaneCore::UI.error("Test Manager Daemon unexpectedly disconnected from test runner")
              FastlaneCore::UI.important("com.apple.CoreSimulator.CoreSimulatorService may have become corrupt, consider quitting it")
              if @scan_options[:quit_core_simulator_service]
                Fastlane::Actions::QuitCoreSimulatorServiceAction.run
                retry if try_count < 3
              end
            end
          end
        end
      end
    end
  end
end
# Ug. How do I name this class?
# I want a class that retries a scan
# I want a class that controls or manages the class that retries the scan and the set up for that
# etc.
# So, the class or the realm could be:
# MultiScanManager
# MultiScanController
# ScanManager
# ScanMaster
# MultiScanMaster
# MasterScanManser
# MasterMultiScan
# I like MultiScanManager