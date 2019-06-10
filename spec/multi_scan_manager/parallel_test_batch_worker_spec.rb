module TestCenter::Helper::MultiScanManager
  describe 'ParallelTestBatchWorker', refactor_retrying_scan:true do
    describe '#run' do
      it 'calls the parent class\'s #run method in a fork block' do
        worker = ParallelTestBatchWorker.new({})
        expect(worker).to receive(:exit!)
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

      it 'updates :pid when forking' do
        worker = ParallelTestBatchWorker.new({})
        allow(Process).to receive(:fork).and_return(11)
        worker.run({})
        expect(worker.pid).to eq(11)
      end

      it 'resets :pid when done' do
        worker = ParallelTestBatchWorker.new({})
        allow(Process).to receive(:fork).and_return(11)
        worker.run({})
        worker.state = :ready_to_work
        expect(worker.pid).to be_nil
      end
    end
  end
end
