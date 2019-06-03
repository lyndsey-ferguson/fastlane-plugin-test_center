module TestCenter::Helper::MultiScanManager
  describe 'TestBatchWorkerPool', refactor_retrying_scan:true do
    describe 'serial' do
      describe '#available_workers' do
        it 'returns an array of 1 TestBatchWorker' do
          pool = TestBatchWorkerPool.new(parallel_simulator_fork_count: 1)
          workers = pool.available_workers
          expect(workers.size).to eq(1)
          worker = workers[0]
          expect(worker.state).to eq(:ready_to_work)
        end
      end
    end

    describe 'parallel' do
      before(:each) do
        @mocked_simulator_helper = OpenStruct.new
        allow(@mocked_simulator_helper).to receive(:setup)
        allow(SimulatorHelper).to receive(:new).and_return(@mocked_simulator_helper)
        
        cloned_simulator_1 = OpenStruct.new(udid: '123')
        cloned_simulator_2 = OpenStruct.new(udid: '123')

        allow(cloned_simulator_1).to receive(:delete)
        allow(cloned_simulator_2).to receive(:delete)

        @mocked_cloned_simulators = [
          [ cloned_simulator_1 ],
          [ cloned_simulator_2 ]
        ]
        allow(@mocked_simulator_helper).to receive(:clone_destination_simulators).and_return(@mocked_cloned_simulators)
      end

      describe '#initialize' do
        it 'creates 4 copies of the simulators in the :destination option' do
          expect(@mocked_simulator_helper).to receive(:clone_destination_simulators).and_return(@mocked_cloned_simulators)
          TestBatchWorkerPool.new(parallel_simulator_fork_count: 4)
        end
      end

      describe '#clean_up_cloned_simulators' do
        it 'deletes the simulators that were created when the pool is created' do
          pool = TestBatchWorkerPool.new(parallel_simulator_fork_count: 2)
          
          expect(@mocked_cloned_simulators.first.first).to receive(:delete)
          expect(@mocked_cloned_simulators.last.first).to receive(:delete)
          
          pool.clean_up_cloned_simulators(@mocked_cloned_simulators)
        end
      end

      describe '#available_workers' do
        it 'returns an array of 4 ParallelTestBatchWorkers' do
          pool = TestBatchWorkerPool.new(parallel_simulator_fork_count: 4)
          workers = pool.available_workers
          expect(workers.size).to eq(4)
          workers.each do |worker|
            expect(worker.state).to eq(:ready_to_work)
          end
        end
      end
    end
  end
end