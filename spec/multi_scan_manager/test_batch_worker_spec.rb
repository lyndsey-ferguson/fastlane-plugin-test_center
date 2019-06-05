module TestCenter::Helper::MultiScanManager
  describe 'TestBatchWorker', refactor_retrying_scan:true do
    describe '#run' do
      it 'calls RetryingScan.run' do
        worker = TestBatchWorker.new({})
        expect(RetryingScan).to receive(:run)
        worker.run({})
      end

      it 'sets :state to working' do
        worker = TestBatchWorker.new({})
        allow(RetryingScan).to receive(:run)
        states = [ worker.state ]
        allow(worker).to receive(:state=) { |new_state| states << new_state }
        worker.run({})
        expect(states).to eq(
          %i[ready_to_work working ready_to_work]
        )
      end
    end
  end
end
