module TestCenter
  module Helper
    module MultiScanManager
      class RetryingScan
        def initialize(options = {})
          @options = options
          @retrying_scan_helper = RetryingScanHelper.new(@options)
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
