
module TestCenter
  module Helper
    module MultiScanManager
      require 'fastlane_core/ui/ui.rb'
      require 'plist'
      require 'json'
      require 'shellwords'
      require 'snapshot/reset_simulators'
      
      class Runner
        attr_reader :retry_total_count

        def initialize(multi_scan_options)
          @options = multi_scan_options.merge(
            clean: false,
            disable_concurrent_testing: true
          )
          @batch_count = 1 # default count. Will be updated by setup_testcollector
          setup_testcollector
        end

        def setup_testcollector
          return if @options[:invocation_based_tests] && @options[:only_testing].nil?
          return if @test_collector

          @test_collector = TestCenter::Helper::TestCollector.new(@options)
          @batch_count = @test_collector.test_batches.size
        end

        def output_directory(batch_index = 0, test_batch = [])
          undecorated_output_directory = File.absolute_path(@options.fetch(:output_directory, 'test_results'))

          return undecorated_output_directory if batch_index.zero?

          absolute_output_directory = undecorated_output_directory

          testable = test_batch.first.split('/').first || ''
          File.join(absolute_output_directory, "#{testable}-batch-#{batch_index}")
        end

        def run
          remove_preexisting_simulator_logs
          remove_preexisting_test_result_bundles

          tests_passed = false
          if should_run_tests_through_single_try?
            tests_passed = run_tests_through_single_try
          end

          unless tests_passed || @options[:try_count] < 1
            setup_testcollector  
            tests_passed = run_test_batches
          end
          tests_passed
        end
        
        def should_run_tests_through_single_try?
          should_run_for_invocation_tests = @options[:invocation_based_tests] && @options[:only_testing].nil?
          should_run_for_skip_build = @options[:skip_build]
          (should_run_for_invocation_tests || should_run_for_skip_build)
        end

        def remove_preexisting_simulator_logs
          return unless @options[:include_simulator_logs]

          glob_pattern = "#{output_directory}/**/system_logs-*.{log,logarchive}"
          logs = Dir.glob(glob_pattern)
          FileUtils.rm_rf(logs)
        end

        def remove_preexisting_test_result_bundles
          return unless @options[:result_bundle]

          glob_pattern = "#{output_directory}/**/*.test_result"
          preexisting_test_result_bundles = Dir.glob(glob_pattern)
          if preexisting_test_result_bundles.size > 0
            FastlaneCore::UI.verbose("Removing pre-existing test_result bundles: ")
            preexisting_test_result_bundles.each do |test_result_bundle|
              FastlaneCore::UI.verbose("  #{test_result_bundle}")
            end
            FileUtils.rm_rf(preexisting_test_result_bundles)
          end
        end

        def run_tests_through_single_try
          FastlaneCore::UI.verbose("Running invocation tests")
          if @options[:invocation_based_tests]
            @options[:skip_testing] = @options[:skip_testing]&.map(&:strip_testcase)&.uniq
          end
          @options[:output_directory] = output_directory
          @options[:destination] = Scan.config[:destination]
          
          # We do not want Scan.config to _not_ have :device :devices, we want to
          # use :destination. We remove :force_quit_simulator as we do not want
          # Scan to handle it as multi_scan takes care of it in its own way
          options = @options.reject { |key| %i[device devices force_quit_simulator].include?(key) }
          options[:try_count] = 1
  
          tests_passed = RetryingScan.run(options)
          @options[:try_count] -= 1
          
          reportnamer = ReportNameHelper.new(
            @options[:output_types],
            @options[:output_files],
            @options[:custom_report_file_name]
          )
          report_filepath = File.join(output_directory, reportnamer.junit_last_reportname)
          config = FastlaneCore::Configuration.create(
            Fastlane::Actions::TestsFromJunitAction.available_options,
            {
              junit: File.absolute_path(report_filepath)
            }
          )
          @options[:only_testing] = retrieve_failed_single_try_tests
          @options[:only_testing] = @options[:only_testing].map(&:strip_testcase).uniq
          
          tests_passed
        end
        
        def retrieve_failed_single_try_tests
          reportnamer = ReportNameHelper.new(
            @options[:output_types],
            @options[:output_files],
            @options[:custom_report_file_name]
          )
          report_filepath = File.join(output_directory, reportnamer.junit_last_reportname)
          config = FastlaneCore::Configuration.create(
            Fastlane::Actions::TestsFromJunitAction.available_options,
            {
              junit: File.absolute_path(report_filepath)
            }
          )
          Fastlane::Actions::TestsFromJunitAction.run(config)[:failed]
        end

        def run_test_batches
          test_batch_results = []
          pool_options = @options.reject { |key| %i[device devices force_quit_simulator].include?(key) }
          pool_options[:test_batch_results] = test_batch_results
          pool_options[:xctestrun] = @test_collector.xctestrun_path

          pool = TestBatchWorkerPool.new(pool_options)
          pool.setup_workers
          
          remaining_test_batches = @test_collector.test_batches.clone
          remaining_test_batches.each_with_index do |test_batch, current_batch_index|
            worker = pool.wait_for_worker              
            FastlaneCore::UI.message("Starting test run #{current_batch_index + 1}")
            worker.run(scan_options_for_worker(test_batch, current_batch_index))
          end
          pool.wait_for_all_workers
          collate_batched_reports
          FastlaneCore::UI.verbose("Results for each test run: #{test_batch_results}")
          test_batch_results.all?
        end

        def scan_options_for_worker(test_batch, batch_index)
          {
            only_testing: test_batch.map(&:shellsafe_testidentifier),
            output_directory: output_directory(batch_index + 1, test_batch),
            try_count: @options[:try_count],
            batch: batch_index + 1
          }
        end
  
        def collate_batched_reports
          return unless @batch_count > 1
          return unless @options[:collate_reports]

          @test_collector.testables.each do |testable|
            collate_batched_reports_for_testable(testable)
          end
          move_single_testable_reports_to_final_location
        end

        def move_single_testable_reports_to_final_location
          return unless @test_collector.testables.size == 1

          report_files_dir = File.join(
            File.absolute_path(output_directory),
            @test_collector.testables.first
          )
          FileUtils.cp_r("#{report_files_dir}/.", File.absolute_path(output_directory))
          FileUtils.rm_rf(report_files_dir)
        end

        def collate_batched_reports_for_testable(testable)
          FastlaneCore::UI.verbose("Collating results for all batches")

          absolute_output_directory = File.join(
            File.absolute_path(output_directory),
            testable
          )
          source_reports_directory_glob = "#{absolute_output_directory}-batch-*"

          given_custom_report_file_name = @options[:custom_report_file_name]
          given_output_types = @options[:output_types]
          given_output_files = @options[:output_files]

          TestCenter::Helper::MultiScanManager::ReportCollator.new(
            source_reports_directory_glob: source_reports_directory_glob,
            output_directory: absolute_output_directory,
            reportnamer: ReportNameHelper.new(
              given_output_types,
              given_output_files,
              given_custom_report_file_name
            ),
            scheme: @options[:scheme],
            result_bundle: @options[:result_bundle]
          ).collate
          FileUtils.rm_rf(Dir.glob(source_reports_directory_glob))
          true
        end
      end
    end
  end
end
