module TestCenter
  module Helper
    module MultiScanManager
      class RetryingScan
        def initialize(options = {})
          @options = options
          @retrying_scan_helper = RetryingScanHelper.new(options)
        end

        def update_scan_options
          valid_scan_keys = Fastlane::Actions::ScanAction.available_options.map(&:key)
          scan_options = @options.select { |k,v| valid_scan_keys.include?(k) }
                                  .merge(@retrying_scan_helper.scan_options)

          scan_options.each do |k,v|
            Scan.config.set(k,v) unless v.nil?
          end
        end

        def run
          try_count = @options[:try_count] || 1
          begin
            # TODO move delete_xcresults to `before_testrun`
            @retrying_scan_helper.before_testrun
            update_scan_options

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
