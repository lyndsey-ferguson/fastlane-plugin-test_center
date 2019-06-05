module TestCenter::Helper::MultiScanManager
  describe 'ParallelTestBatchWorker', refactor_retrying_scan:true do
    describe '#run' do
      it 'calls the parent class\'s #run method in a fork block' do
        worker = ParallelTestBatchWorker.new({})
        expect(Process).to receive(:fork) do |&block|
          expect(RetryingScan).to receive(:run)
          block.call()
        end
        worker.run({})
      end
    end
  end
end
