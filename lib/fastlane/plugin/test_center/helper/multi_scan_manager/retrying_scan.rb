require 'pry-byebug'
module TestCenter
  module Helper
    module MultiScanManager
      class RetryingScan
        def initialize(scan_options, retrying_scan_helper)
          @scan_options = scan_options
          @retrying_scan_helper = retrying_scan_helper
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
            @retrying_scan_helper.refactor_retrying_scan(e)
            retry if try_count < 3
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