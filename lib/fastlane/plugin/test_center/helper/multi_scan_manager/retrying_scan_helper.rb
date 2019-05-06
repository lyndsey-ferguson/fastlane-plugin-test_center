module TestCenter
  module Helper
    module MultiScanManager
      require_relative 'device_manager'

      class RetryingScanHelper

        def initialize(options)
          raise ArgumentError, 'Do not use the :device or :devices option. Instead use the :destination option.' if (options.key?(:device) or options.key?(:devices))

          @options = options
          @testrun_count = 0
          @xcpretty_json_file_output = ENV['XCPRETTY_JSON_FILE_OUTPUT']

          @reportnamer = ReportNameHelper.new(
            options[:output_types],
            options[:output_files],
            options[:custom_report_file_name]
          )
        end
        
        def before_testrun
          remove_preexisting_test_result_bundles
          set_json_env
        end

        def set_json_env
          return unless @reportnamer.includes_json?

          ENV['XCPRETTY_JSON_FILE_OUTPUT'] = File.join(
            @options[:output_directory],
            @reportnamer.json_last_reportname
          )
        end

        def reset_json_env
          return unless @reportnamer.includes_json?

          ENV['XCPRETTY_JSON_FILE_OUTPUT'] = @xcpretty_json_file_output
        end

        def remove_preexisting_test_result_bundles
          return unless @options[:result_bundle]

          absolute_output_directory = File.absolute_path(@options[:output_directory])
          glob_pattern = "#{absolute_output_directory}/*.test_result"
          preexisting_test_result_bundles = Dir.glob(glob_pattern)
          FileUtils.rm_rf(preexisting_test_result_bundles)
        end

        def scan_options
          valid_scan_keys = Fastlane::Actions::ScanAction.available_options.map(&:key)
          @options.select { |k,v| valid_scan_keys.include?(k) }
                  .merge(@reportnamer.scan_options)
        end

        # after_testrun methods

        def after_testrun(exception = nil)
          @testrun_count = @testrun_count + 1
          if exception.kind_of?(FastlaneCore::Interface::FastlaneTestFailure)
            handle_test_failure
          elsif exception.kind_of?(FastlaneCore::Interface::FastlaneBuildFailure)
            handle_build_failure(exception)
          else
            handle_success
          end
        end

        def handle_success
          move_test_result_bundle_for_next_run
          reset_json_env
        end

        def handle_test_failure
          reset_simulators
          update_scan_options
          @reportnamer.increment
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
          report_filepath = File.join(@options[:output_directory], @reportnamer.junit_last_reportname)
          config = FastlaneCore::Configuration.create(
            Fastlane::Actions::TestsFromJunitAction.available_options,
            {
              junit: File.absolute_path(report_filepath)
            }
          )
          @options[:only_testing] = Fastlane::Actions::TestsFromJunitAction.run(config)[:failed]
        end
        
        def reset_simulators
          return unless @options[:reset_simulators]

          @options[:simulators].each(&:reset)
        end

        def handle_build_failure(exception)
          derived_data_path = File.expand_path(@options[:derived_data_path])
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
            if @options[:quit_core_simulator_service]
              Fastlane::Actions::RestartCoreSimulatorServiceAction.run
            else
            end
          else
            raise exception
          end
          if @options[:reset_simulators]
            @options[:simulators].each do |simulator|
              simulator.reset
            end
          end
        end

        def move_test_result_bundle_for_next_run
          return unless @options[:result_bundle]

          absolute_output_directory = File.absolute_path(@options[:output_directory])
          glob_pattern = "#{absolute_output_directory}/*.test_result"
          preexisting_test_result_bundles = Dir.glob(glob_pattern)
          unnumbered_test_result_bundles = preexisting_test_result_bundles.reject do |test_result|
            test_result =~ /.*-\d+\.test_result/
          end
          src_test_bundle = unnumbered_test_result_bundles.first
          dst_test_bundle_parent_dir = File.dirname(src_test_bundle)
          dst_test_bundle_basename = File.basename(src_test_bundle, '.test_result')
          dst_test_bundle = "#{dst_test_bundle_parent_dir}/#{dst_test_bundle_basename}-#{@testrun_count}.test_result"
          FileUtils.mkdir_p(dst_test_bundle)
          FileUtils.mv(src_test_bundle, dst_test_bundle)
        end
      end
    end
  end
end
