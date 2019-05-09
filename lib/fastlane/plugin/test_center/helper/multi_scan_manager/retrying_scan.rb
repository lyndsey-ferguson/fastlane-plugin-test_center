require 'pry-byebug'
module TestCenter
  module Helper
    module MultiScanManager
      class RetryingScan
        def initialize(scan_options = {})
          @scan_options = scan_options
          @retrying_scan_helper = RetryingScanHelper.new(scan_options)
        end

        def run
          try_count = @scan_options[:try_count] || 1
          begin
            valid_scan_keys = Fastlane::Actions::ScanAction.available_options.map(&:key)
            config = FastlaneCore::Configuration.create(
              Fastlane::Actions::ScanAction.available_options,
              @scan_options.select { |k,v| valid_scan_keys.include?(k) }
            )

            Fastlane::Actions::ScanAction.run(config)
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