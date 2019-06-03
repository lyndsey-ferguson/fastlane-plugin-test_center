module TestCenter::Helper::MultiScanManager
  describe 'TestBatchWorker', refactor_retrying_scan:true do
    describe '#run' do
      it 'calls RetryingScan.run' do
        worker = TestBatchWorker.new({})
        expect(RetryingScan).to receive(:run)
        worker.run({})
      end
    end
  end
end
