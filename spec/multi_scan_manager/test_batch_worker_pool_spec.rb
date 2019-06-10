
require 'pry-byebug'

module TestCenter::Helper::MultiScanManager
  describe 'TestBatchWorkerPool', refactor_retrying_scan:true do
    describe 'serial' do
      describe '#wait_for_worker' do
        it 'returns an array of 1 TestBatchWorker' do
          pool = TestBatchWorkerPool.new(parallel_simulator_fork_count: 1)
          pool.setup_workers
          worker = pool.wait_for_worker
          expect(worker.state).to eq(:ready_to_work)
        end
      end
    end

    describe 'parallel' do
      before(:each) do
        @mocked_simulator_helper = OpenStruct.new
        allow(@mocked_simulator_helper).to receive(:setup)
        allow(SimulatorHelper).to receive(:new).and_return(@mocked_simulator_helper)
        allow(Dir).to receive(:mktmpdir).and_return('/tmp/TestBatchWorkerPool')
        allow(FileUtils).to receive(:cp_r).with(anything, %r{/tmp/TestBatchWorkerPool})
        allow(FileUtils).to receive(:rm_rf).with(%r{/tmp/TestBatchWorkerPool})

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

      describe '#setup_workers' do
        it 'creates 4 copies of the simulators in the :destination option' do
          expect(@mocked_simulator_helper).to receive(:clone_destination_simulators).and_return(@mocked_cloned_simulators)
          TestBatchWorkerPool.new(parallel_simulator_fork_count: 4).setup_workers
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
        
        it 'clones a copy of the xcode build products directory for each worker' do
          pool = TestBatchWorkerPool.new(parallel_simulator_fork_count: 4, xctestrun: './path/to/fake/build/products/xctestrun')
          expect(pool).to receive(:clone_temporary_xcbuild_products_dir).exactly(4).times
          pool.setup_workers
        end
        
        it 'updates the :buildlog_path for each worker' do
          pool = TestBatchWorkerPool.new(parallel_simulator_fork_count: 4, buildlog_path: './path/to/fake/build/logs')
          expect(pool).to receive(:buildlog_path_for_worker).exactly(4).times
          pool.setup_workers
        end

        skip 'updates the :derived_data_path for each worker', ':derived_data_path is not being tested sufficiently' do
          pool = TestBatchWorkerPool.new(parallel_simulator_fork_count: 4, xctestrun: './path/to/fake/build/products/xctestrun')
          expect(pool).to receive(:derived_data_path_for_worker).exactly(4).times
          pool.setup_workers
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

        describe '#setup_cloned_simulators' do
          skip 'provides simulator clones'
          skip 'cleans up cloned simulators only when exiting from the main process'
        end

        describe '#clone_temporary_xcbuild_products_dir' do
          skip 'makes a copy in a temporary directory of the build products directory', ':xcrunpath is not being properly tested' do
            pool = TestBatchWorkerPool.new(
              {
                parallel_simulator_fork_count: 4,
                xctestrun: './path/to/Build/Products/AtomicTornado.xctestrun'
              }
            )
            allow(Dir).to receive(:mktmpdir).and_return("/tmp/1")

            expect(FileUtils).to receive(:copy_entry).with(
              %r{\./path/to/Build/Products},
              %r{/tmp/1}
            )
            pool.clone_temporary_xcbuild_products_dir
          end
        end

        describe '#buildlog_path_for_worker' do
          it 'creates a subdirectory for each worker in the :buildlog_path' do
            pool = TestBatchWorkerPool.new(
              {
                parallel_simulator_fork_count: 4,
                buildlog_path: './path/to/build/log'
              }
            )
            
            expect(pool.buildlog_path_for_worker(1)).to match(%r{path/to/build/log/parallel-simulators-1-logs})
          end
        end

        describe '#derived_data_path_for_worker' do
          it 'creates a temporary derived data path for each worker' do
            pool = TestBatchWorkerPool.new(
              {
                parallel_simulator_fork_count: 4,
              }
            )
            allow(Dir).to receive(:mktmpdir).and_return("/tmp/derived_data_path/1")

            expect(pool.derived_data_path_for_worker(1)).to match("/tmp/derived_data_path/1")
          end
        end
      end

      describe '#wait_for_worker' do
        it 'returns 4 ParallelTestBatchWorkers if each has not started working' do
          pool = TestBatchWorkerPool.new(parallel_simulator_fork_count: 4)
          pool.setup_workers
          workers =  (1..4).map do
            worker = pool.wait_for_worker
            worker.state = :working
            worker
          end
          expect(workers.uniq.size).to eq(4)
        end

        it 'returns an array of 5 ParallelTestBatchWorker when one was working' do
          mocked_workers = [
            OpenStruct.new(state: :ready_to_work),
            OpenStruct.new(state: :ready_to_work),
            OpenStruct.new(state: :ready_to_work),
            OpenStruct.new(state: :ready_to_work)
          ]
          allow(ParallelTestBatchWorker).to receive(:new) { mocked_workers.shift }
          
          pids = [99, 1, 2, 3, 4, 5]
          allow(Process).to receive(:wait) { pids.shift }

          pool = TestBatchWorkerPool.new(parallel_simulator_fork_count: 4)
          pool.setup_workers
          
          workers =  (1..5).map do |index|
            worker = pool.wait_for_worker
            worker.state = :working
            worker.pid = index
            worker
          end
          expect(workers.size).to eq(5)
          expect(workers.uniq.size).to eq(4)
        end
      end

      skip '#wait_for_all_workers'
    end
  end
end