
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
          @test_collector = TestCenter::Helper::TestCollector.new(multi_scan_options)
          @options = multi_scan_options.merge(
            clean: false,
            disable_concurrent_testing: true
          )
          @batch_count = @test_collector.test_batches.size
        end

        def output_directory
          @options.fetch(:output_directory, 'test_results')
        end

        def run
          remove_preexisting_test_result_bundles

          if @options[:invocation_based_tests]
            run_invocation_based_tests
          else
            run_test_batches
          end
        end
        
        def remove_preexisting_test_result_bundles
          return unless @options[:result_bundle]

          glob_pattern = "#{output_directory}/**/*.test_result"
          preexisting_test_result_bundles = Dir.glob(glob_pattern)
          FileUtils.rm_rf(preexisting_test_result_bundles)
        end

        def run_invocation_based_tests
          @options[:only_testing] = @options[:only_testing]&.map(&:strip_testcase)&.uniq
          @options[:skip_testing] = @options[:skip_testing]&.map(&:strip_testcase)&.uniq
          
          RetryingScan.run(@options.reject { |key| %i[device devices force_quit_simulator].include?(key) } )
        end
        
        def run_test_batches
          test_batch_results = []
          pool_options = @options.reject { |key| %i[device devices force_quit_simulator].include?(key) }
          pool_options[:test_batch_results] = test_batch_results

          pool = TestBatchWorkerPool.new(pool_options)
          pool.setup_workers
          
          remaining_test_batches = @test_collector.test_batches.clone
          remaining_test_batches.each_with_index do |test_batch, current_batch_index|
            worker = pool.wait_for_worker              
            FastlaneCore::UI.message("Starting test run #{current_batch_index}")
            worker.run(scan_options_for_worker(test_batch, current_batch_index))
          end
          pool.wait_for_all_workers
          collate_batched_reports
          test_batch_results.reduce(true) { |a, t| a && t }
        end

        def scan_options_for_worker(test_batch, batch_index)
          {
            only_testing: test_batch.map(&:shellsafe_testidentifier),
            output_directory: output_directory,
            try_count: @options[:try_count],
            batch: batch_index + 1,
            xctestrun: @test_collector.xctestrun_path
          }
        end
  
        def collate_batched_reports
          return unless @batch_count > 1
          return unless @options[:collate_reports]


          @test_collector.testables.each do |testable|
            collate_batched_reports_for_testable(testable)
          end
        end

        def collate_batched_reports_for_testable(testable)
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

