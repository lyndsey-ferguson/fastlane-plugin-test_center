module TestCenter
  module Helper
    module MultiScanManager
      class RetryingScan
        def initialize(options = {})
          @options = options
          @retrying_scan_helper = RetryingScanHelper.new(options)
        end

        def delete_xcresults
          derived_data_path = File.expand_path(scan_config[:derived_data_path])
          xcresults = Dir.glob("#{derived_data_path}/Logs/Test/*.xcresult")
          FastlaneCore::UI.message("Deleting xcresults: #{xcresults}")
          FileUtils.rm_rf(xcresults)
        end

        def scan_config
          if Scan.config.nil?
            Scan.config = FastlaneCore::Configuration.create(
              Fastlane::Actions::ScanAction.available_options,
              @options.select { |k,v| %i[project workspace scheme].include?(k) }
            )
          end
          Scan.config
        end

        def update_scan_options
          valid_scan_keys = Fastlane::Actions::ScanAction.available_options.map(&:key)
          scan_options = @options.select { |k,v| valid_scan_keys.include?(k) }
                                  .merge(@retrying_scan_helper.scan_options)

          sc = scan_config
          scan_options.each do |k,v|
            sc.set(k,v) unless v.nil?
          end
        end

        def run
          try_count = @options[:try_count] || 1
          begin
            # TODO move delete_xcresults to `before_testrun`
            @retrying_scan_helper.before_testrun
            update_scan_options
            delete_xcresults # has to be performed _after_ moving a *.test_result

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
