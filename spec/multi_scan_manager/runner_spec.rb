module TestCenter::Helper::MultiScanManager
  describe 'Runner' do
    before(:each) do
      @mock_test_collector = OpenStruct.new(
        test_batches: [],
        xctestrun_path: ''
      )
      allow(TestCenter::Helper::TestCollector).to receive(:new).and_return(@mock_test_collector)
      @use_refactored_parallelized_multi_scan = ENV['USE_REFACTORED_PARALLELIZED_MULTI_SCAN']
    end

    after(:each) do
      ENV['USE_REFACTORED_PARALLELIZED_MULTI_SCAN'] = @use_refactored_parallelized_multi_scan
    end

    describe '#update_options_to_use_xcresult_output' do
      it 'does nothing when :result_bundle is false' do
        runner = Runner.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          output_directory: './path/to/output/directory'
        )
        expect(runner.update_options_to_use_xcresult_output).to eq(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          output_directory: './path/to/output/directory',
          clean: false,
          disable_concurrent_testing: true
        )
      end
      it 'returns options without :result_bundle' do
        allow(FastlaneCore::Helper).to receive(:xcode_at_least?).and_return(true)
        runner = Runner.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          output_directory: './path/to/output/directory',
          result_bundle: true,
          output_types: 'junit',
          output_files: 'report.junit'
        )
        expect(runner.update_options_to_use_xcresult_output).to eq(
          output_directory: './path/to/output/directory',
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          clean: false,
          disable_concurrent_testing: true,
          output_files: 'report.junit,report.xcresult',
          output_types: 'junit,xcresult'
        )
      end
    end

    describe '#output_directory' do
      it 'returns the :output_directory directly if no batches given' do
        runner = Runner.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          output_directory: './path/to/output/directory'
        )
        expect(runner.output_directory).to eq(File.absolute_path('./path/to/output/directory'))
      end

      it 'returns the \'test_results\' if no batches and output_directory given' do
        runner = Runner.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr'
        )
        expect(runner.output_directory).to eq(File.absolute_path('./test_results'))
      end

      it 'returns the :output_directory plus the batch if batches given' do
        runner = Runner.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          output_directory: './path/to/output/directory',
          only_testing: [
            'Bag Of Tests/CoinTossingUITests/testResultIsTails',
            'Bag Of Tests/CoinTossingUITests/testResultIsHeads',
            'Bag Of Tests/CoinTossingUITests/testResultIsOnEdge'
          ],
          batch: 4
        )
        expect(runner.output_directory(4, ['Bag Of Tests/CoinTossingUITests/testResultIsTails'])).to eq(File.absolute_path('./path/to/output/directory/Bag Of Tests-batch-4'))
      end
    end

    describe '#remove_preexisting_test_result_bundles' do
      it 'clears out pre-existing test bundles' do
        allow(Dir).to receive(:glob).with(%r{.*/path/to/output/directory/\*\*/\*\.test_result}).and_return(['./AtomicDragon.test_result'])
        allow(FastlaneCore::Helper).to receive(:xcode_at_least?).and_return(false)
        runner = Runner.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          output_directory: './path/to/output/directory',
          result_bundle: true,
          try_count: 1
        )
        expect(FileUtils).to receive(:rm_rf).with(['./AtomicDragon.test_result'])
        runner.remove_preexisting_test_result_bundles
      end
    end

    describe '#run' do
      before(:each) do
        @xctest_runner = Runner.new(
          {
            output_directory: './path/to/output/directory',
            scheme: 'AtomicUITests',
            try_count: 1
          }
        )

        allow(@xctest_runner).to receive(:setup_testcollector)
        allow(@xctest_runner).to receive(:run_test_batches).and_return(true)
        allow(@xctest_runner).to receive(:run_first_run_of_invocation_based_tests).and_return(true)
        allow(@xctest_runner).to receive(:symlink_result_bundle_to_xcresult)
      end

      it 'calls :remove_preexisting_test_result_bundles' do
        expect(@xctest_runner).to receive(:remove_preexisting_test_result_bundles)
        @xctest_runner.run
      end

      it 'runs test batches when appropriate' do
        expect(@xctest_runner).to receive(:run_test_batches)
        @xctest_runner.run
      end

      it 'runs :run_tests_through_single_try when given :invocation_based_tests' do
        runner = Runner.new(
          {
            output_directory: './path/to/output/directory',
            scheme: 'AtomicUITests',
            try_count: 2,
            invocation_based_tests: true
          }
        )
        expect(runner).to receive(:run_tests_through_single_try)
        expect(runner).to receive(:run_test_batches)
        runner.run
      end

      it 'runs :run_tests_through_single_try when given :skip_build' do
        runner = Runner.new(
          {
            output_directory: './path/to/output/directory',
            scheme: 'AtomicUITests',
            try_count: 2,
            skip_build: true
          }
        )
        expect(runner).to receive(:run_tests_through_single_try)
        expect(runner).to receive(:run_test_batches)
        runner.run
      end

      it 'does not run single_try_scan when not appropriate' do
        invocation_runner = Runner.new(
          {
            output_directory: './path/to/output/directory',
            scheme: 'AtomicUITests',
            try_count: 1,
            invocation_based_tests: true,
            only_testing: [ 
              'KiwiTests/PumpkinTests',
              'KiwiTests/SmallBirdTests',
              'KiwiTests/CruddogTests',
              'KiwiTests/KiwiDemoTests'
            ]
          }
        )
        expect(invocation_runner).not_to receive(:run_tests_through_single_try)
        expect(invocation_runner).to receive(:run_test_batches)
        invocation_runner.run
      end
    end

    describe '#run_invocation_based_tests' do
      it 'strips test cases off of skip_testing:' do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(%r{.*/path/to/output/directory/report(-\d)?\.junit}).and_return(true)
        allow(Fastlane::Actions::TestsFromJunitAction).to receive(:run).and_return(
          failed: [ 
            'KiwiTests/PumpkinTests',
            'KiwiTests/SmallBirdTests',
            'KiwiTests/CruddogTests',
            'KiwiTests/KiwiDemoTests'
          ]
        )
        allow(Scan).to receive(:config).and_return({ destination: ['iPhone 5s,id=ABCDEFGHIJ']})
        
        runner = Runner.new(
          {
            output_directory: './path/to/output/directory',
            scheme: 'AtomicUITests',
            skip_testing: [
              'AllMyTestTargets/testUnicorns/testcase1',
              'AllMyTestTargets/testDragons/testcase1'
            ],
            invocation_based_tests: true,
            try_count: 1
          }
        )
        runner.instance_variable_set(:@test_collector, @mock_test_collector)
        expect(RetryingScan).to receive(:run) do |options|
          expect(options).to include(
            skip_testing: [
              'AllMyTestTargets/testUnicorns',
              'AllMyTestTargets/testDragons'
            ]
          )
          true
        end
        runner.run
      end
    end

    describe '#run_test_batches' do
      describe 'serial batches' do  
        it 'calls a test_worker for each test batch' do
          mocked_testbatch_worker = OpenStruct.new
          allow(RetryingScan).to receive(:run)
          allow(TestBatchWorker).to receive(:new).and_return(mocked_testbatch_worker)
          allow(@mock_test_collector).to receive(:test_batches).and_return(
            [
              ['AtomicBoyTests/testOne'],
              ['AtomicBoyUITests/testOne']
            ]
          )
          
          runner = Runner.new(
            {
              output_directory: './path/to/output/directory',
              scheme: 'AtomicUITests',
              try_count: 2
            }
          )
          runner.instance_variable_set(:@batch_count, 2)
          runner.instance_variable_set(:@test_collector, @mock_test_collector)

          allow(runner).to receive(:collate_batched_reports)
          expect(mocked_testbatch_worker).to receive(:run) do |options|
            expect(options).to include(batch: 1)
          end
          expect(mocked_testbatch_worker).to receive(:run) do |options|
            expect(options).to include(batch: 2)
          end
          runner.run
        end
      end

      it 'returns true if all test_batch_worker runs return true' do
        mocked_testbatch_worker = OpenStruct.new
          allow(RetryingScan).to receive(:run)
          allow(TestBatchWorker).to receive(:new).and_return(mocked_testbatch_worker)
          allow(@mock_test_collector).to receive(:test_batches).and_return(
            [
              ['AtomicBoyTests/testOne'],
              ['AtomicBoyUITests/testOne']
            ]
          )
          
          runner = Runner.new(
            {
              output_directory: './path/to/output/directory',
              scheme: 'AtomicUITests',
              try_count: 2
            }
          )
          runner.instance_variable_set(:@test_collector, @mock_test_collector)
          allow(runner).to receive(:collate_batched_reports)

          expect(mocked_testbatch_worker).to receive(:run).and_return(true).twice
          run_passed = runner.run
          expect(run_passed).to eq(true)
      end

      it 'returns false when even one test_batch_worker runs return false' do
          mocked_testbatch_worker = OpenStruct.new
          allow(RetryingScan).to receive(:run)
          
          test_test_batch_results = nil
          allow(TestBatchWorker).to receive(:new) do |options|
            test_test_batch_results = options[:test_batch_results]
            mocked_testbatch_worker
          end
          allow(@mock_test_collector).to receive(:test_batches).and_return(
            [
              ['AtomicBoyTests/testOne'],
              ['AtomicBoyUITests/testOne']
            ]
          )
          
          runner = Runner.new(
            {
              output_directory: './path/to/output/directory',
              scheme: 'AtomicUITests',
              try_count: 2
            }
          )
          runner.instance_variable_set(:@test_collector, @mock_test_collector)

          allow(runner).to receive(:collate_batched_reports)

          expect(mocked_testbatch_worker).to receive(:run) { | anytthing | test_test_batch_results << true }
          expect(mocked_testbatch_worker).to receive(:run) { | anytthing | test_test_batch_results << false }
          
          run_passed = runner.run
          expect(run_passed).to eq(false)
      end
    end

    describe 'collate_batched_reports' do
      it 'does nothing if there are fewer than 2 batches' do
        runner = Runner.new({})
        expect(runner).not_to receive(:collate_batched_reports_for_testable)
        runner.collate_batched_reports
      end

      it 'collates batches of reports for the one testable' do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(%r{.*/path/to/output/directory/BagOfTests-batch-(\d)/report(-\d)?\.junit}).and_return(true)
        allow(@mock_test_collector).to receive(:testables).and_return([ 'BagOfTests' ])
        allow(@mock_test_collector).to receive(:test_batches).and_return([ '1', '2'])
        runner = Runner.new(
          {
            output_directory: './path/to/output/directory',
            scheme: 'AtomicUITests',
            collate_reports: true
          }
        )
        runner.instance_variable_set(:@batch_count, 2)
        runner.instance_variable_set(:@test_collector, @mock_test_collector)

        mocked_report_collator = OpenStruct.new
        expect(TestCenter::Helper::MultiScanManager::ReportCollator).to receive(:new)
          .with(
            source_reports_directory_glob: File.absolute_path('./path/to/output/directory/BagOfTests-batch-*'),
            output_directory: File.absolute_path('./path/to/output/directory/BagOfTests'),
            reportnamer: anything,
            scheme: 'AtomicUITests',
            result_bundle: nil
          )
          .and_return(mocked_report_collator)
        expect(mocked_report_collator).to receive(:collate)
        expect(FileUtils).to receive(:cp_r).with(
          %r{.*/path/to/output/directory/BagOfTests/\.},
          %r{.*/path/to/output/directory}
        )
        allow(FileUtils).to receive(:rm_rf).and_call_original
        expect(FileUtils).to receive(:rm_rf).with(%r{.*/path/to/output/directory/BagOfTest})

        runner.collate_batched_reports
      end

      it 'does not collate reports if not desired' do
        runner = Runner.new(
          {
            output_directory: './path/to/output/directory',
            scheme: 'AtomicUITests',
            collate_reports: false,
            batch_count: 2
          }
        )
        mocked_report_collator = OpenStruct.new
        allow(TestCenter::Helper::MultiScanManager::ReportCollator).to receive(:new).and_return(mocked_report_collator)
        expect(mocked_report_collator).not_to receive(:collate)
        runner.collate_batched_reports
      end

      it 'collates batches of reports for two testables' do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(%r{.*/path/to/output/directory/BagOfTests-batch-(\d)/report(-\d)?\.junit}).and_return(true)
        allow(@mock_test_collector).to receive(:testables).and_return([ 'BagOfTests', 'WarehouseOfFun'])
        allow(@mock_test_collector).to receive(:test_batches).and_return([ '1', '2'])
        runner = Runner.new(
          {
            output_directory: './path/to/output/directory',
            scheme: 'AtomicUITests',
            collate_reports: true
          }
        )
        runner.instance_variable_set(:@batch_count, 2)
        runner.instance_variable_set(:@test_collector, @mock_test_collector)
        mocked_report_collator = OpenStruct.new
        expect(TestCenter::Helper::MultiScanManager::ReportCollator).to receive(:new)
          .with(
            source_reports_directory_glob: File.absolute_path('./path/to/output/directory/BagOfTests-batch-*'),
            output_directory: File.absolute_path('./path/to/output/directory/BagOfTests'),
            reportnamer: anything,
            scheme: 'AtomicUITests',
            result_bundle: nil
          )
          .ordered
          .and_return(mocked_report_collator)
        expect(mocked_report_collator).to receive(:collate)

        expect(TestCenter::Helper::MultiScanManager::ReportCollator).to receive(:new)
          .with(
            source_reports_directory_glob: File.absolute_path('./path/to/output/directory/WarehouseOfFun-batch-*'),
            output_directory: File.absolute_path('./path/to/output/directory/WarehouseOfFun'),
            reportnamer: anything,
            scheme: 'AtomicUITests',
            result_bundle: nil
          )
          .ordered
          .and_return(mocked_report_collator)
        expect(mocked_report_collator).to receive(:collate)

        runner.collate_batched_reports
      end
    end

    describe '#symlink_result_bundle_to_xcresult' do
      it 'creates a symlink to an xcresult file when output_types includes xcresult' do
        allow(FileUtils).to receive(:rm_rf).with('path/to/result.test_result')
        expect(File).to receive(:symlink).with('path/to/result.xcresult', 'path/to/result.test_result')

        runner = Runner.new(
          {
            output_directory: 'path/to/output/directory',
            scheme: 'AtomicUITests',
            collate_reports: true,
            result_bundle: true
          }
        )

        reportname_helper = ReportNameHelper.new(
          'xcresult',
          'result.xcresult',
          nil
        )
        allow(reportname_helper).to receive(:includes_xcresult?).and_return(true)
        runner.symlink_result_bundle_to_xcresult('path/to', reportname_helper)
      end

      it 'does nothing if output_types does not include xcresult' do
        expect(File).not_to receive(:symlink).with('path/to/result.xcresult', 'path/to/result.test_result')

        runner = Runner.new(
          {
            output_directory: 'path/to/output/directory',
            scheme: 'AtomicUITests',
            collate_reports: true,
          }
        )

        reportname_helper = ReportNameHelper.new(
          'junit',
          'result.xml',
          nil
        )
        allow(reportname_helper).to receive(:includes_xcresult?).and_return(false)
        runner.symlink_result_bundle_to_xcresult('path/to', reportname_helper)
      end
    end
  end
end
