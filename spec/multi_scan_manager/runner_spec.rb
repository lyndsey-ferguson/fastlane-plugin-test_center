module TestCenter::Helper::MultiScanManager
  describe 'Runner', refactor_retrying_scan:true do
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