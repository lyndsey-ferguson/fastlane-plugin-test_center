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

      it 'sets :state to working' do
        worker = ParallelTestBatchWorker.new({})
        allow(Process).to receive(:fork)
        states = [ worker.state ]
        allow(worker).to receive(:state=) { |new_state| states << new_state }
        worker.run({})
        expect(states).to eq(
          %i[ready_to_work working]
        )
      end
    end
  end
end
