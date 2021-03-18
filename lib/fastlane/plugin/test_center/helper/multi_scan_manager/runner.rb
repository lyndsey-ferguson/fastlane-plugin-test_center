module TestCenter
  module Helper
    module MultiScanManager
      require 'fastlane_core/ui/ui.rb'
      require 'plist'
      require 'json'
      require 'shellwords'
      require 'snapshot/reset_simulators'
      require_relative '../fastlane_core/device_manager/simulator_extensions'

      class Runner
        attr_reader :retry_total_count

        def initialize(multi_scan_options)
          @options = multi_scan_options.merge(
            clean: false,
            disable_concurrent_testing: true
          )
          @result_bundle_desired = !!@options[:result_bundle]
          if @options[:result_bundle] && FastlaneCore::Helper.xcode_at_least?('11.0.0')
            update_options_to_use_xcresult_output
          end
          @batch_count = 1 # default count. Will be updated by setup_testcollector
          @options[:parallel_testrun_count] ||= 1
          @initial_parallel_testrun_count = @options[:parallel_testrun_count]
          setup_testcollector
          setup_logcollection
          FastlaneCore::UI.verbose("< done in TestCenter::Helper::MultiScanManager.initialize")
        end

        def update_options_to_use_xcresult_output
          return @options unless @options[:result_bundle]

          updated_output_types, updated_output_files = ReportNameHelper.ensure_output_includes_xcresult(
            @options[:output_types],
            @options[:output_files]
          )
          @options[:output_types] = updated_output_types
          @options[:output_files] = updated_output_files
          @options.reject! { |k,_| k == :result_bundle }
        end

        def setup_logcollection
          FastlaneCore::UI.verbose("> setup_logcollection")
          return unless @options[:include_simulator_logs]
          return unless @options[:platform] == :ios_simulator
          return if Scan::Runner.method_defined?(:prelaunch_simulators)

          # We need to prelaunch the simulators so xcodebuild
          # doesn't shut it down before we have a chance to get
          # the logs.
          FastlaneCore::UI.verbose("\t collecting devices to boot for log collection")
          devices_to_shutdown = []
          Scan.devices.each do |device|
            devices_to_shutdown << device if device.state == "Shutdown"
            device.boot
          end
          at_exit do
            devices_to_shutdown.each(&:shutdown)
          end
          FastlaneCore::UI.verbose("\t fixing FastlaneCore::Simulator.copy_logarchive")
          FastlaneCore::Simulator.send(:include, FixedCopyLogarchiveFastlaneSimulator)
        end

        def setup_testcollector
          return if @options[:invocation_based_tests] && @options[:only_testing].nil?
          return if @test_collector

          @test_collector = TestCollector.new(@options)
          @options.reject! { |key| %i[testplan].include?(key) }
          @batch_count = @test_collector.batches.size
          @options[:parallel_testrun_count] = @initial_parallel_testrun_count
          tests = @test_collector.batches.flatten
          if tests.size < @options[:parallel_testrun_count].to_i
            FastlaneCore::UI.important(":parallel_testrun_count greater than the number of tests (#{tests.size}). Reducing to that number.")
            @options[:parallel_testrun_count] = tests.size
          end
        end

        def output_directory(batch_index = 0, test_batch = [])
          undecorated_output_directory = File.absolute_path(@options.fetch(:output_directory, 'test_results'))

          return undecorated_output_directory if batch_index.zero?

          absolute_output_directory = undecorated_output_directory

          testable = test_batch.first.split('/').first || ''
          File.join(absolute_output_directory, "#{testable}-batch-#{batch_index}")
        end

        def run
          ScanHelper.remove_preexisting_simulator_logs(@options)
          remove_preexisting_test_result_bundles
          remote_preexisting_xcresult_bundles

          test_results = [false]
          if should_run_tests_through_single_try?
            test_results.clear
            setup_run_tests_for_each_device do |device_name|
              FastlaneCore::UI.message("Single try testing for device '#{device_name}'") if device_name
              test_results << run_tests_through_single_try
            end
          end

          unless test_results.all? || @options[:try_count] < 1
            test_results.clear
            setup_testcollector
            setup_run_tests_for_each_device do |device_name|
              FastlaneCore::UI.message("Testing batches for device '#{device_name}'") if device_name
              test_results << run_test_batches
            end
          end
          test_results.all?
        end

        def setup_run_tests_for_each_device
          original_output_directory = @options.fetch(:output_directory, 'test_results')
          unless @options[:platform] == :ios_simulator
            yield
            return
          end

          scan_destinations = Scan.config[:destination].clone
          try_count = @options[:try_count]

          scan_destinations.each_with_index do |destination, device_index|
            @options[:try_count] = try_count
            device_udid_match = destination.match(/id=(?<udid>[^,]+)/)
            device_udid = device_udid_match[:udid] if device_udid_match
            if scan_destinations.size > 1
              @options[:output_directory] = File.join(original_output_directory, device_udid)
              Scan.config[:destination].replace([destination])
            end
            command = "xcrun simctl list devices | grep #{device_udid}"
            device_info = Fastlane::Actions.sh(command, log: false)

            yield device_info.strip.gsub(/ \(#{device_udid}.*/, '')
          end
          Scan.config[:destination].replace(scan_destinations)
          @options[:output_directory] = original_output_directory
        end

        def should_run_tests_through_single_try?
          @options[:invocation_based_tests] && @options[:only_testing].nil?
        end


        def remove_preexisting_test_result_bundles
          return unless @options[:result_bundle] || @options[:output_types]&.include?('xcresult')

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

        def remote_preexisting_xcresult_bundles
          return unless @options.fetch(:output_types, '').include?('xcresult')

          glob_pattern = "#{output_directory}/**/*.xcresult"
          preexisting_xcresult_bundles = Dir.glob(glob_pattern)
          if preexisting_xcresult_bundles.size > 0
            FastlaneCore::UI.verbose("Removing pre-existing xcresult bundles: ")
            preexisting_xcresult_bundles.each do |test_result_bundle|
              FastlaneCore::UI.verbose("  #{test_result_bundle}")
            end
            FileUtils.rm_rf(preexisting_xcresult_bundles)
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

          SimulatorHelper.call_simulator_started_callback(@options, Scan.devices)

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

          symlink_result_bundle_to_xcresult(output_directory, reportnamer)

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

          serial_test_batches = (@options.fetch(:parallel_testrun_count, 1) == 1)
          if serial_test_batches && !@options[:invocation_based_tests]
            SimulatorHelper.call_simulator_started_callback(@options, Scan.devices)
          end

          pool = TestBatchWorkerPool.new(pool_options)
          pool.setup_workers

          remaining_test_batches = @test_collector.batches.clone
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
          if @test_collector.batches.size > 1
            # If there are more than 1 batch, then we want each batch result
            # sent to a "batch index" output folder to be collated later
            # into the requested output_folder.
            # Otherwise, send the results from the one and only one batch
            # to the requested output_folder
            batch_index += 1
            batch = batch_index
          end

          {
            only_testing: test_batch.map(&:shellsafe_testidentifier),
            output_directory: output_directory(batch_index, test_batch),
            try_count: @options[:try_count],
            batch: batch
          }
        end

        def collate_batched_reports
          return unless @batch_count > 1
          return unless @options[:collate_reports]

          @test_collector.testables.each do |testable|
            collate_batched_reports_for_testable(testable)
          end
          collate_multitarget_junits
          move_single_testable_reports_to_final_location
        end

        def move_single_testable_reports_to_final_location
          return unless @test_collector.testables.size == 1

          report_files_dir = File.join(
            File.absolute_path(output_directory),
            @test_collector.testables.first
          )
          merge_single_testable_xcresult_with_final_xcresult(report_files_dir, File.absolute_path(output_directory))
          FileUtils.cp_r("#{report_files_dir}/.", File.absolute_path(output_directory))
          FileUtils.rm_rf(report_files_dir)
        end

        def merge_single_testable_xcresult_with_final_xcresult(testable_output_dir, final_output_dir)
          reportnamer = ReportNameHelper.new(
            @options[:output_types],
            @options[:output_files],
            @options[:custom_report_file_name]
          )
          return unless reportnamer.includes_xcresult?

          xcresult_bundlename = reportnamer.xcresult_bundlename
          src_xcresult_bundlepath = File.join(testable_output_dir, xcresult_bundlename)
          dst_xcresult_bundlepath = File.join(final_output_dir, xcresult_bundlename)

          # if there is no destination bundle to merge to, skip it as any source bundle will be copied when complete.
          return if !File.exist?(dst_xcresult_bundlepath)
          # if there is no source bundle to merge, skip it as there is nothing to merge.
          return if !File.exist?(src_xcresult_bundlepath)

          config = FastlaneCore::Configuration.create(
            Fastlane::Actions::CollateXcresultsAction.available_options,
            {
              xcresults: [src_xcresult_bundlepath, dst_xcresult_bundlepath],
              collated_xcresult: dst_xcresult_bundlepath
            }
          )
          FastlaneCore::UI.verbose("Merging xcresult '#{src_xcresult_bundlepath}' to '#{dst_xcresult_bundlepath}'")
          Fastlane::Actions::CollateXcresultsAction.run(config)
          FileUtils.rm_rf(src_xcresult_bundlepath)
          if @result_bundle_desired
            xcresult_bundlename = reportnamer.xcresult_bundlename
            test_result_bundlename = File.basename(xcresult_bundlename, '.*') + '.test_result'
            test_result_bundlename_path = File.join(testable_output_dir, test_result_bundlename)
            FileUtils.rm_rf(test_result_bundlename_path)
          end
        end

        def symlink_result_bundle_to_xcresult(output_dir, reportname_helper)
          return unless @result_bundle_desired && reportname_helper.includes_xcresult?

          xcresult_bundlename = reportname_helper.xcresult_bundlename
          xcresult_bundlename_path = File.join(output_dir, xcresult_bundlename)
          test_result_bundlename = File.basename(xcresult_bundlename, '.*') + '.test_result'
          test_result_bundlename_path = File.join(output_dir, test_result_bundlename)
          FileUtils.rm_rf(test_result_bundlename_path)
          File.symlink(xcresult_bundlename_path, test_result_bundlename_path)
        end

        def collate_multitarget_junits
          return if @test_collector.testables.size < 2

          Fastlane::UI.verbose("Collating test targets's junit results")

          given_custom_report_file_name = @options[:custom_report_file_name]
          given_output_types = @options[:output_types]
          given_output_files = @options[:output_files]

          report_name_helper = ReportNameHelper.new(
            given_output_types,
            given_output_files,
            given_custom_report_file_name
          )

          absolute_output_directory = File.absolute_path(output_directory)
          source_reports_directory_glob = "#{absolute_output_directory}/*"
          FastlaneCore::UI.verbose("MultiScanManager::Runner sending 'source_reports_directory_glob' of \"#{source_reports_directory_glob}\"")
          TestCenter::Helper::MultiScanManager::ReportCollator.new(
            source_reports_directory_glob: source_reports_directory_glob,
            output_directory: absolute_output_directory,
            reportnamer: report_name_helper
          ).collate_junit_reports
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

          report_name_helper = ReportNameHelper.new(
            given_output_types,
            given_output_files,
            given_custom_report_file_name
          )

          TestCenter::Helper::MultiScanManager::ReportCollator.new(
            source_reports_directory_glob: source_reports_directory_glob,
            output_directory: absolute_output_directory,
            reportnamer: report_name_helper,
            scheme: @options[:scheme],
            result_bundle: @options[:result_bundle]
          ).collate
          logs_glog_pattern = "#{source_reports_directory_glob}/*system_logs-*.{log,logarchive}"
          logs = Dir.glob(logs_glog_pattern)
          FileUtils.mv(logs, absolute_output_directory, force: true)
          FileUtils.rm_rf(Dir.glob(source_reports_directory_glob))
          symlink_result_bundle_to_xcresult(absolute_output_directory, report_name_helper)
          true
        end
      end
    end
  end
end
