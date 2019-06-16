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

    describe '#run' do
      it 'runs test batches when appropriate' do
        runner = Runner.new(
          {
            output_directory: './path/to/output/directory',
            scheme: 'AtomicUITests'
          }
        )
        expect(runner).to receive(:run_test_batches)
        runner.run
      end

      it 'runs invocation tests when appropriate' do
        runner = Runner.new(
          {
            output_directory: './path/to/output/directory',
            scheme: 'AtomicUITests',
            invocation_based_tests: true
          }
        )
        expect(runner).to receive(:run_invocation_based_tests)
        runner.run
      end
    end

    describe '#run_invocation_based_tests' do
      it 'strips test cases off of only_testing:' do
        runner = Runner.new(
          {
            output_directory: './path/to/output/directory',
            scheme: 'AtomicUITests',
            only_testing: [
              'AllMyTestTargets/testUnicorns/testcase1',
              'AllMyTestTargets/testUnicorns/testcase2'
            ],
            invocation_based_tests: true
          }
        )
        expect(RetryingScan).to receive(:run) do |options|
          expect(options).to include(
            only_testing: ['AllMyTestTargets/testUnicorns']
          )
        end
        runner.run
      end

      it 'strips test cases off of skip_testing:' do
        runner = Runner.new(
          {
            output_directory: './path/to/output/directory',
            scheme: 'AtomicUITests',
            skip_testing: [
              'AllMyTestTargets/testUnicorns/testcase1',
              'AllMyTestTargets/testDragons/testcase1'
            ],
            invocation_based_tests: true
          }
        )
        expect(RetryingScan).to receive(:run) do |options|
          expect(options).to include(
            skip_testing: [
              'AllMyTestTargets/testUnicorns',
              'AllMyTestTargets/testDragons'
            ]
          )
        end
        runner.run
      end

      it 'does not have only_testing: or skip_testing:' do
        runner = Runner.new(
          {
            output_directory: './path/to/output/directory',
            scheme: 'AtomicUITests',
            invocation_based_tests: true
          }
        )
        expect(RetryingScan).to receive(:run) do |options|
          expect(options).to include(
            skip_testing: nil,
            only_testing: nil
          )
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
              scheme: 'AtomicUITests'
            }
          )
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
              scheme: 'AtomicUITests'
            }
          )
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
              scheme: 'AtomicUITests'
            }
          )
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
        expect(runner.collate_batched_reports).to eq(false)
      end

      it 'collates batches of reports for the one testable' do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(%r{.*/path/to/output/directory/BagOfTests-batch-(\d)/report(-\d)?\.junit}).and_return(true)
        allow(@mock_test_collector).to receive(:testables).and_return([ 'BagOfTests' ])
        allow(@mock_test_collector).to receive(:test_batches).and_return([ '1', '2'])
        runner = Runner.new(
          {
            output_directory: './path/to/output/directory',
            scheme: 'AtomicUITests'
          }
        )
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

        expect(runner.collate_batched_reports).to eq(true)
      end

      it 'collates batches of reports for two testables' do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(%r{.*/path/to/output/directory/BagOfTests-batch-(\d)/report(-\d)?\.junit}).and_return(true)
        allow(@mock_test_collector).to receive(:testables).and_return([ 'BagOfTests', 'WarehouseOfFun'])
        allow(@mock_test_collector).to receive(:test_batches).and_return([ '1', '2'])
        runner = Runner.new(
          {
            output_directory: './path/to/output/directory',
            scheme: 'AtomicUITests'
          }
        )
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

        expect(runner.collate_batched_reports).to eq(true)
      end
    end
  end
end
