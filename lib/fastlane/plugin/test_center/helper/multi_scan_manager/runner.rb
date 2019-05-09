
module TestCenter
  module Helper
    module MultiScanManager
      require 'fastlane_core/ui/ui.rb'
      require 'plist'
      require 'json'
      require 'shellwords'
      require_relative './simulator_manager'

      class Runner
        Parallelization = TestCenter::Helper::MultiScanManager::Parallelization

        attr_reader :retry_total_count

        def initialize(multi_scan_options)
          @output_directory = multi_scan_options[:output_directory] || 'test_results'
          @try_count = multi_scan_options[:try_count]
          @retry_total_count = 0
          @testrun_completed_block = multi_scan_options[:testrun_completed_block]
          @given_custom_report_file_name = multi_scan_options[:custom_report_file_name]
          @given_output_types = multi_scan_options[:output_types]
          @given_output_files = multi_scan_options[:output_files]
          @parallelize = multi_scan_options[:parallelize]
          @test_collector = TestCenter::Helper::TestCollector.new(multi_scan_options)
          @scan_options = multi_scan_options.reject do |option, _|
            %i[
              output_directory
              only_testing
              skip_testing
              clean
              try_count
              batch_count
              custom_report_file_name
              fail_build
              testrun_completed_block
              output_types
              output_files
              parallelize
              quit_simulators
            ].include?(option)
          end
          @scan_options[:clean] = false
          @scan_options[:disable_concurrent_testing] = true
          @scan_options[:xctestrun] = @test_collector.xctestrun_path
          @batch_count = @test_collector.test_batches.size
          if @parallelize
            @scan_options.delete(:derived_data_path)
            @parallelizer = Parallelization.new(@batch_count, @output_directory, @testrun_completed_block)
          end
        end

        def scan
          all_tests_passed = true
          @testables_count = @test_collector.testables.size
          all_tests_passed = each_batch do |test_batch, current_batch_index|
            output_directory = testrun_output_directory(@output_directory, test_batch, current_batch_index)
            if ENV['USE_REFACTORED_PARALLELIZED_MULTI_SCAN']
              retrying_scan = TestCenter::Helper::MultiScanManager::RetryingScan.new(
                @scan_options.merge(
                  only_testing: test_batch.map(&:shellsafe_testidentifier),
                  output_directory: output_directory,
                  destination: @parallelizer&.destination_for_batch(current_batch_index) || Scan.config[:destination]
                ).reject { |key| %i[device devices].include?(key) }
              )
              retrying_scan.run
            else
              reset_for_new_testable(output_directory)
              FastlaneCore::UI.header("Starting test run on batch '#{current_batch_index}'")
              @interstitial.batch = current_batch_index
              @interstitial.output_directory = output_directory
              @interstitial.before_all
              testrun_passed = correcting_scan(
                {
                  only_testing: test_batch.map(&:shellsafe_testidentifier),
                  output_directory: output_directory
                },
                current_batch_index,
                @reportnamer
              )
              all_tests_passed = testrun_passed && all_tests_passed
              TestCenter::Helper::MultiScanManager::ReportCollator.new(
                source_reports_directory_glob: output_directory,
                output_directory: output_directory,
                reportnamer: @reportnamer,
                scheme: @scan_options[:scheme],
                result_bundle: @scan_options[:result_bundle]
              ).collate
            end
            testrun_passed && all_tests_passed
          end
          all_tests_passed
        end

        def each_batch
          tests_passed = true
          if @parallelize
            xctestrun_filename = File.basename(@test_collector.xctestrun_path)
            xcproduct_dirpath = File.dirname(@test_collector.xctestrun_path)
            tmp_xcproduct_dirpath = Dir.mktmpdir

            FileUtils.copy_entry(xcproduct_dirpath, tmp_xcproduct_dirpath)

            tmp_xctestrun_path = File.join(tmp_xcproduct_dirpath, xctestrun_filename)
            app_infoplist = XCTestrunInfo.new(tmp_xctestrun_path)
            @scan_options[:xctestrun] = tmp_xctestrun_path
            batch_deploymentversions = @test_collector.test_batches.map do |test_batch|
              testable = test_batch.first.split('/').first.gsub('\\', '')
              # TODO: investigate the reason for this call that doesn't seem to do
              # anything other than query for and then discard MinimumOSVersion
              app_infoplist.app_plist_for_testable(testable)['MinimumOSVersion']
            end
            @parallelizer.setup_simulators(@scan_options[:devices] || Array(@scan_options[:device]), batch_deploymentversions)
            @parallelizer.setup_pipes_for_fork
            @test_collector.test_batches.each_with_index do |test_batch, current_batch_index|
              fork do
                @parallelizer.connect_subprocess_endpoint(current_batch_index)
                begin
                  @parallelizer.setup_scan_options_for_testrun(@scan_options, current_batch_index)
                  # add output_directory to map of test-target: [ output_directories ]
                  tests_passed = yield(test_batch, current_batch_index)
                ensure
                  @parallelizer.send_subprocess_result(current_batch_index, tests_passed)
                end
                # processes to disconnect from the Simulator subsystems
                FastlaneCore::UI.message("batched scan #{current_batch_index} finishing")
              end
            end
            # @parallelizer.wait_for_subprocesses
            # tests_passed = @parallelizer.handle_subprocesses_results && tests_passed
            @parallelizer.handle_subprocesses
            @parallelizer.cleanup_simulators
            @test_collector.testables.each do |testable|
              # ReportCollator with a testable-batch glob pattern
              source_reports_directory_glob = batched_testable_output_directory(@output_directory, '*', testable)
              @reportnamer = ReportNameHelper.new(
                @given_output_types,
                @given_output_files,
                @given_custom_report_file_name
              )
              TestCenter::Helper::MultiScanManager::ReportCollator.new(
                source_reports_directory_glob: source_reports_directory_glob,
                output_directory: @output_directory,
                reportnamer: @reportnamer,
                scheme: @scan_options[:scheme],
                result_bundle: @scan_options[:result_bundle],
                suffix: testable
              ).collate
              FileUtils.rm_rf(Dir.glob(source_reports_directory_glob))
            end
            # for each key in test-target : [ output_directories ], call
            # collate_junit_reports for each key, the [ output_directories ] being
            # used to find the report files.
            # the resultant report file is to be placed in the originally requested
            # output_directory, with the name changed to include a suffix matching
            # the test target's name
          else
            @test_collector.test_batches.each_with_index do |test_batch, current_batch_index|
              tests_passed = yield(test_batch, current_batch_index)
            end
          end
          tests_passed
        end

        def batched_testable_output_directory(output_directory, batch_index, testable_name)
          File.join(output_directory, "results-#{testable_name}-batch-#{batch_index}")
        end

        def testrun_output_directory(base_output_directory, test_batch, batch_index)
          return base_output_directory if @batch_count == 1

          testable_name = test_batch.first.split('/').first.gsub(/\\/, '')
          batched_testable_output_directory(base_output_directory, batch_index, testable_name)
        end

        def reset_reportnamer
          @reportnamer = ReportNameHelper.new(
            @given_output_types,
            @given_output_files,
            @given_custom_report_file_name
          )
        end

        def test_run_completed_callback
          if @parallelize && @testrun_completed_block
            Proc.new do |info|
              puts "about to call @parallelizer.send_subprocess_tryinfo(#{info})"
              @parallelizer.send_subprocess_tryinfo(info)
            end
          else
            @testrun_completed_block
          end
        end

        def reset_interstitial(output_directory)
          @interstitial = TestCenter::Helper::MultiScanManager::Interstitial.new(
            @scan_options.merge(
              {
                output_directory: output_directory,
                reportnamer: @reportnamer,
                testrun_completed_block: @testrun_completed_block,
                parallelize: @parallelize
              }
            )
          )
        end

        def reset_for_new_testable(output_directory)
          reset_reportnamer
          reset_interstitial(output_directory)
        end

        def correcting_scan(scan_run_options, batch, reportnamer)
          scan_options = @scan_options.merge(scan_run_options)
          try_count = 0
          tests_passed = true
          begin
            try_count += 1
            config = FastlaneCore::Configuration.create(
              Fastlane::Actions::ScanAction.available_options,
              scan_options.merge(reportnamer.scan_options)
            )
            Fastlane::Actions::ScanAction.run(config)
            @interstitial.finish_try(try_count)
            tests_passed = true
          rescue FastlaneCore::Interface::FastlaneTestFailure => e
            FastlaneCore::UI.verbose("Scan failed with #{e}")
            if try_count < @try_count
              @retry_total_count += 1
              scan_options.delete(:code_coverage)
              tests_to_retry = failed_tests(reportnamer, scan_options[:output_directory])

              scan_options[:only_testing] = tests_to_retry.map(&:shellsafe_testidentifier)
              FastlaneCore::UI.message('Re-running scan on only failed tests')
              @interstitial.finish_try(try_count)
              retry
            end
            tests_passed = false
          end
          tests_passed
        end

        def failed_tests(reportnamer, output_directory)
          report_filepath = File.join(output_directory, reportnamer.junit_last_reportname)
          config = FastlaneCore::Configuration.create(
            Fastlane::Actions::TestsFromJunitAction.available_options,
            {
              junit: File.absolute_path(report_filepath)
            }
          )
          Fastlane::Actions::TestsFromJunitAction.run(config)[:failed]
        end
      end
    end
  end
end


module FastlaneCore
  class Shell < Interface
    def format_string(datetime = Time.now, severity = "")
      prefix = $batch_index.nil? ? '' : "#{$batch_index}: "
      if FastlaneCore::Globals.verbose?
        return "#{prefix}#{severity} [#{datetime.strftime('%Y-%m-%d %H:%M:%S.%2N')}]: "
      elsif FastlaneCore::Env.truthy?("FASTLANE_HIDE_TIMESTAMP")
        return prefix
      else
        return "#{prefix}[#{datetime.strftime('%H:%M:%S')}]: "
      end
    end
  end
end
