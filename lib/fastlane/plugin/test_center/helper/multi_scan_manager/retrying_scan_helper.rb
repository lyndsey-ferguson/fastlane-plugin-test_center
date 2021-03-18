module TestCenter
  module Helper
    module MultiScanManager
      class RetryingScanHelper

        attr_reader :testrun_count

        def initialize(options)
          raise ArgumentError, 'Do not use the :device or :devices option. Instead use the :destination option.' if (options.key?(:device) or options.key?(:devices))

          @options = options
          FastlaneCore::UI.verbose("RetryingScanHelper.initialize with ':output' as \"#{@options[:output_directory]}\"")
          @testrun_count = 0
          @xcpretty_json_file_output = ENV['XCPRETTY_JSON_FILE_OUTPUT']
          @reportnamer = ReportNameHelper.new(
            @options[:output_types],
            @options[:output_files],
            @options[:custom_report_file_name]
          )
          @callback_overrides_only_testing = false
        end

        def before_testrun
          delete_xcresults # has to be performed _after_ moving a *.test_result
          quit_simulator
          set_json_env
          set_scan_config
          print_starting_scan_message
        end

        def set_scan_config
          valid_scan_keys = Fastlane::Actions::ScanAction.available_options.map(&:key)
          new_scan_options = @options.select { |k,v| valid_scan_keys.include?(k) }
                                 .merge(scan_options)

          prepare_scan_config
          new_scan_options[:build_for_testing] = false
          new_scan_options.delete(:skip_testing)

          new_scan_options = send_callback_override_scan_options_block(new_scan_options)

          FastlaneCore::UI.verbose("retrying_scan #update_scan_options")
          new_scan_options.each do |k,v|
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

          values = scan_config.values(ask: false)
          values[:xcode_path] = File.expand_path("../..", FastlaneCore::Helper.xcode_path)
          ScanHelper.print_scan_parameters(values)
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
          scan_cache.clear
        end

        def send_callback_override_scan_options_block(new_scan_options)
          return new_scan_options unless @options[:override_scan_options_block]

          callback_result = @options[:override_scan_options_block].call(new_scan_options)
          if callback_result.kind_of?(Hash)
            return callback_result
          end
          new_scan_options
        end

        def quit_simulator
          return unless @options[:quit_simulators]

          @options.fetch(:destination).each do |destination|
            if /id=(?<udid>[^,$]+)/ =~ destination
              FastlaneCore::UI.verbose("Restarting Simulator #{udid}")
              `xcrun simctl shutdown #{udid} 2>/dev/null`
              `xcrun simctl boot #{udid} 2>/dev/null`
            end
          end
        end

        def delete_xcresults
          if @reportnamer.includes_xcresult?
            FileUtils.rm_rf(File.join(output_directory, @reportnamer.xcresult_last_bundlename))
            return
          end

          derived_data_path = File.expand_path(@options[:derived_data_path] || Scan.config[:derived_data_path])
          xcresults = Dir.glob("#{derived_data_path}/Logs/Test/*.xcresult")
          if FastlaneCore::Helper.xcode_at_least?('11')
            xcresults += Dir.glob("#{output_directory}/*.xcresult")
          end
          FastlaneCore::UI.verbose("Deleting xcresults:")
          xcresults.each do |xcresult|
            FastlaneCore::UI.verbose("  #{xcresult}")
          end
          FileUtils.rm_rf(xcresults)
        end

        def output_directory
          @options.fetch(:output_directory, 'test_results')
        end

        def print_starting_scan_message
          if @options[:only_testing]
            scan_message = "Starting scan ##{@testrun_count + 1} with #{@options.fetch(:only_testing, []).size} tests"
          else
            scan_message = "Starting scan ##{@testrun_count + 1}"
          end
          scan_message << " for batch ##{@options[:batch]}" unless @options[:batch].nil?
          FastlaneCore::UI.message("#{scan_message}.")
        end

        def set_json_env
          return unless @reportnamer.includes_json?

          xcpretty_json_file_output = File.join(
            output_directory,
            @reportnamer.json_last_reportname
          )
          FastlaneCore::UI.verbose("Setting the XCPRETTY_JSON_FILE_OUTPUT to #{xcpretty_json_file_output}")
          ENV['XCPRETTY_JSON_FILE_OUTPUT'] = xcpretty_json_file_output
        end

        def reset_json_env
          return unless @reportnamer.includes_json?

          ENV['XCPRETTY_JSON_FILE_OUTPUT'] = @xcpretty_json_file_output
        end

        def scan_options
          valid_scan_keys = Fastlane::Actions::ScanAction.available_options.map(&:key)
          xcargs = @options[:xcargs] || ''
          if xcargs&.include?('build-for-testing')
            FastlaneCore::UI.important(":xcargs, #{xcargs}, contained 'build-for-testing', removing it")
            xcargs.slice!('build-for-testing')
          end
          if xcargs.include?('-quiet')
            FastlaneCore::UI.important('Disabling -quiet as failing tests cannot be found with it enabled.')
            xcargs.gsub!('-quiet', '')
          end
          if FastlaneCore::Helper.xcode_at_least?(10)
            xcargs.gsub!(/-parallel-testing-enabled(=|\s+)(YES|NO)/, '')
            xcargs << " -parallel-testing-enabled NO "
          end
          retrying_scan_options = @reportnamer.scan_options.merge(
            {
              output_directory: output_directory,
              xcargs: xcargs
            }
          )
          if @reportnamer.includes_xcresult?
            retrying_scan_options[:xcargs] += "-resultBundlePath '#{File.join(output_directory, @reportnamer.xcresult_last_bundlename)}' "
          end

          @options.select { |k,v| valid_scan_keys.include?(k) }
            .merge(retrying_scan_options)
        end

        # after_testrun methods

        def after_testrun(exception = nil)
          move_simulator_logs_for_next_run

          @testrun_count = @testrun_count + 1
          FastlaneCore::UI.verbose("Batch ##{@options[:batch]} incrementing retry count to #{@testrun_count}")
          if exception.kind_of?(FastlaneCore::Interface::FastlaneTestFailure)
            after_testrun_message = "Scan found failing tests"
            after_testrun_message << " for batch ##{@options[:batch]}" unless @options[:batch].nil?
            FastlaneCore::UI.verbose(after_testrun_message)

            handle_test_failure
          elsif exception.kind_of?(FastlaneCore::Interface::FastlaneBuildFailure)
            after_testrun_message = "Scan unable to test"
            after_testrun_message << " for batch ##{@options[:batch]}" unless @options[:batch].nil?
            FastlaneCore::UI.verbose(after_testrun_message)

            if @options[:retry_test_runner_failures]
              continue_with_build_failure(exception)
            else
              handle_build_failure(exception)
            end
          else
            after_testrun_message = "Scan passed the tests"
            after_testrun_message << " for batch ##{@options[:batch]}" unless @options[:batch].nil?
            FastlaneCore::UI.verbose(after_testrun_message)

            handle_success
          end
          collate_reports
        end

        def handle_success
          send_callback_testrun_info
          move_test_result_bundle_for_next_run
          reset_json_env
        end

        def collate_reports
          return unless @options[:collate_reports]

          report_collator_options = {
            source_reports_directory_glob: output_directory,
            output_directory: output_directory,
            reportnamer: @reportnamer,
            scheme: @options[:scheme],
            result_bundle: @options[:result_bundle]
          }
          TestCenter::Helper::MultiScanManager::ReportCollator.new(report_collator_options).collate
        end

        def handle_test_failure
          send_callback_testrun_info
          move_test_result_bundle_for_next_run
          update_scan_options
          @reportnamer.increment
        end

        def send_callback_testrun_info(additional_info = {})
          return unless @options[:testrun_completed_block]

          report_filepath = nil
          junit_results, report_filepath = failure_details(additional_info)

          info = {
            failed: junit_results.fetch(:failed, []),
            passing: junit_results.fetch(:passing, []),
            batch: @options[:batch] || 1,
            try_count: @testrun_count,
            report_filepath: report_filepath
          }.merge(additional_info)

          update_html_failure_details(info)
          update_json_failure_details(info)
          update_test_result_bundle_details(info)

          @callback_overrides_only_testing = false
          callback_result = @options[:testrun_completed_block].call(info)
          if callback_result.kind_of?(Hash)
            should_continue = callback_result.fetch(:continue, true)
            if !should_continue
              discontinue_message = 'Following testrun_completed_block\'s request to discontinue testing'
              discontinue_message << " for batch ##{@options[:batch]}" unless @options[:batch].nil?
              FastlaneCore::UI.verbose(discontinue_message)
              @testrun_count = options[:try_count]
            end
            overridden_only_testing = callback_result.fetch(:only_testing, nil)
            if overridden_only_testing && should_continue
              override_only_testing_message = 'Following testrun_completed_block\'s request to change :only_testing to '
              override_only_testing_message << overridden_only_testing.to_s
              override_only_testing_message << " for batch ##{@options[:batch]}" unless @options[:batch].nil?
              FastlaneCore::UI.verbose(override_only_testing_message)
              @callback_overrides_only_testing = true
              @options[:only_testing] = overridden_only_testing
            end
          end
        end

        def failure_details(additional_info)
          return [{}, nil] if additional_info.key?(:test_operation_failure)

          report_filepath = File.join(output_directory, @reportnamer.junit_last_reportname)
          config = FastlaneCore::Configuration.create(
            Fastlane::Actions::TestsFromJunitAction.available_options,
            {
              junit: File.absolute_path(report_filepath)
            }
          )
          junit_results = Fastlane::Actions::TestsFromJunitAction.run(config)

          [junit_results, report_filepath]
        end

        def update_html_failure_details(info)
          return unless @reportnamer.includes_html?

          html_report_filepath = File.join(output_directory, @reportnamer.html_last_reportname)
          info[:html_report_filepath] = html_report_filepath
        end

        def update_json_failure_details(info)
          return unless @reportnamer.includes_json?

          json_report_filepath = File.join(output_directory, @reportnamer.json_last_reportname)
          info[:json_report_filepath] = json_report_filepath
        end

        def update_test_result_bundle_details(info)
          return unless @options[:result_bundle]

          test_result_suffix = '.test_result'
          test_result_suffix.prepend("-#{@reportnamer.report_count}") unless @reportnamer.report_count.zero?
          test_result_bundlepath = File.join(output_directory, @options[:scheme]) + test_result_suffix
          info[:test_result_bundlepath] = test_result_bundlepath
        end

        def update_scan_options
          update_only_testing
          turn_off_code_coverage
        end

        def turn_off_code_coverage
          # Turn off code coverage as code coverage reports are not merged and
          # the first, more valuable, report will be overwritten
          @options.delete(:code_coverage)
        end

        def update_only_testing
          return if @callback_overrides_only_testing

          report_filepath = File.join(output_directory, @reportnamer.junit_last_reportname)
          config = FastlaneCore::Configuration.create(
            Fastlane::Actions::TestsFromJunitAction.available_options,
            {
              junit: File.absolute_path(report_filepath)
            }
          )
          @options[:only_testing] = (@options[:only_testing] || []) - Fastlane::Actions::TestsFromJunitAction.run(config).fetch(:passing, Hash.new).map(&:shellsafe_testidentifier)
          if @options[:invocation_based_tests]
            @options[:only_testing] = @options[:only_testing].map(&:strip_testcase).uniq
          end
        end

        def continue_with_build_failure(exception)
          test_session_last_messages = last_lines_of_test_session_log
          failure = retrieve_test_operation_failure(test_session_last_messages)
          case failure
          when /Lost connection to testmanagerd/
            FastlaneCore::UI.important("com.apple.CoreSimulator.CoreSimulatorService may have become corrupt, consider quitting it")
            if @options[:quit_core_simulator_service]
              Fastlane::Actions::RestartCoreSimulatorServiceAction.run
            end
          else
            FastlaneCore::UI.important(test_session_last_messages)
          end
          send_callback_testrun_info(test_operation_failure: failure)
        end

        def handle_build_failure(exception)
          test_session_last_messages = last_lines_of_test_session_log
          failure = retrieve_test_operation_failure(test_session_last_messages)
          case failure
          when /Test runner exited before starting test execution/
            FastlaneCore::UI.error(failure)
          when /Lost connection to testmanagerd/
            FastlaneCore::UI.error(failure)
            FastlaneCore::UI.important("com.apple.CoreSimulator.CoreSimulatorService may have become corrupt, consider quitting it")
            if @options[:quit_core_simulator_service]
              Fastlane::Actions::RestartCoreSimulatorServiceAction.run
            end
          else
            FastlaneCore::UI.error(test_session_last_messages)
            send_callback_testrun_info(test_operation_failure: failure)
            raise exception
            FastlaneCore::UI.important(test_session_last_messages)
          end
          send_callback_testrun_info(test_operation_failure: failure)
        end

        def retrieve_test_operation_failure(test_session_last_messages)
          if FastlaneCore::Helper.xcode_at_least?('11')
            retrieve_test_operation_failure_post_xcode11(test_session_last_messages)
          else
            retrieve_test_operation_failure_pre_xcode11(test_session_last_messages)
          end
        end

        def retrieve_test_operation_failure_post_xcode11(test_session_last_messages)
          if /Connection peer refused channel request/ =~ test_session_last_messages
            test_operation_failure = 'Lost connection to testmanagerd'
          elsif /Please unlock your device and reattach/ =~ test_session_last_messages
            test_operation_failure = 'Test device locked'
          elsif /Test runner exited before starting test execution/ =~ test_session_last_messages
            test_operation_failure = 'Test runner exited before starting test execution'
          else
            test_operation_failure = 'Unknown test operation failure'
          end
          test_operation_failure
        end

        def retrieve_test_operation_failure_pre_xcode11(test_session_last_messages)
          test_operation_failure_match = /Test operation failure: (?<test_operation_failure>.*)$/ =~ test_session_last_messages
          if test_operation_failure_match.nil?
            test_operation_failure = 'Unknown test operation failure'
          end
          test_operation_failure
        end

        def last_lines_of_test_session_log
          derived_data_path = File.expand_path(@options[:derived_data_path])
          test_session_logs = Dir.glob("#{derived_data_path}/Logs/Test/*.xcresult/*_Test/Diagnostics/**/Session-*.log")
          return '' if test_session_logs.empty?

          test_session_logs.sort! { |logfile1, logfile2| File.mtime(logfile1) <=> File.mtime(logfile2) }
          test_session = File.open(test_session_logs.last)
          backwards_seek_offset = -1 * [1000, test_session.stat.size].min
          test_session.seek(backwards_seek_offset, IO::SEEK_END)
          test_session_last_messages = test_session.read
        end

        def move_simulator_logs_for_next_run
          return unless @options[:include_simulator_logs]

          glob_pattern = "#{output_directory}/system_logs-*.{log,logarchive}"
          logs = Dir.glob(glob_pattern)
          batch_prefix = ''
          if @options[:batch]
            batch_prefix = "batch-#{@options[:batch]}-"
          end
          logs.each do |log_filepath|
            new_logname = "#{batch_prefix}try-#{testrun_count}-#{File.basename(log_filepath)}"
            new_log_filepath = "#{File.dirname(log_filepath)}/#{new_logname}"
            FastlaneCore::UI.verbose("Moving simulator log '#{log_filepath}' to '#{new_log_filepath}'")
            FileUtils.mv(log_filepath, new_log_filepath, force: true)
          end
        end

        def move_test_result_bundle_for_next_run
          return unless @options[:result_bundle]

          result_extension = FastlaneCore::Helper.xcode_at_least?('11') ? '.xcresult' : '.test_result'

          glob_pattern = "#{output_directory}/*#{result_extension}"
          preexisting_test_result_bundles = Dir.glob(glob_pattern)
          unnumbered_test_result_bundles = preexisting_test_result_bundles.reject do |test_result|
            test_result =~ /.*-\d+\#{result_extension}/
          end
          src_test_bundle = unnumbered_test_result_bundles.first
          dst_test_bundle_parent_dir = File.dirname(src_test_bundle)
          dst_test_bundle_basename = File.basename(src_test_bundle, result_extension)
          dst_test_bundle = "#{dst_test_bundle_parent_dir}/#{dst_test_bundle_basename}-#{@testrun_count}#{result_extension}"
          FastlaneCore::UI.verbose("Moving test_result '#{src_test_bundle}' to '#{dst_test_bundle}'")
          File.rename(src_test_bundle, dst_test_bundle)
        end
      end
    end
  end
end
