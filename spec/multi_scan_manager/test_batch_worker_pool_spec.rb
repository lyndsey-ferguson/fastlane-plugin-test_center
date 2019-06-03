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
        cloned_simulator_2 = OpenStruct.new(udid: '456')
        cloned_simulator_3 = OpenStruct.new(udid: '789')
        cloned_simulator_4 = OpenStruct.new(udid: 'A00')

        allow(cloned_simulator_1).to receive(:delete)
        allow(cloned_simulator_2).to receive(:delete)
        allow(cloned_simulator_3).to receive(:delete)
        allow(cloned_simulator_4).to receive(:delete)

        @mocked_cloned_simulators = [
          [ cloned_simulator_1 ],
          [ cloned_simulator_2 ],
          [ cloned_simulator_3 ],
          [ cloned_simulator_4 ]
        ]
        allow(@mocked_simulator_helper).to receive(:clone_destination_simulators).and_return(@mocked_cloned_simulators)
      end

      describe '#initialize' do
        it 'creates 4 copies of the simulators in the :destination option' do
          expect(@mocked_simulator_helper).to receive(:clone_destination_simulators).and_return(@mocked_cloned_simulators)
          TestBatchWorkerPool.new(parallel_simulator_fork_count: 4)
        end
      end

      describe '#destination_from_simulators' do
        it 'creates a :destination array with a string for one simulator' do
          pool = TestBatchWorkerPool.new(parallel_simulator_fork_count: 4)
          destination = pool.destination_from_simulators(@mocked_cloned_simulators[3])
          expect(destination).to eq(["platform=iOS Simulator,id=A00"])
        end

        it 'creates a :destination array with two strings for two simulators' do
          pool = TestBatchWorkerPool.new(parallel_simulator_fork_count: 4)
          destination = pool.destination_from_simulators(
            [
              @mocked_cloned_simulators[2].first,
              @mocked_cloned_simulators[1].first
            ]
          )
          expect(destination).to eq(["platform=iOS Simulator,id=789", "platform=iOS Simulator,id=456"])
        end
      end

      describe '#clean_up_cloned_simulators' do
        it 'deletes the simulators that were created when the pool is created' do
          pool = TestBatchWorkerPool.new(parallel_simulator_fork_count: 4)
          
          @mocked_cloned_simulators.flatten.each do |simulator|
            expect(simulator).to receive(:delete)
          end
          
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