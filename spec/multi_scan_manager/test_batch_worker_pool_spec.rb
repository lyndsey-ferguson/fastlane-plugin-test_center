module TestCenter::Helper::MultiScanManager
  describe 'TestBatchWorkerPool' do
    describe 'serial' do
      describe '#wait_for_worker' do
        it 'returns an array of 1 TestBatchWorker' do
          pool = TestBatchWorkerPool.new(parallel_testrun_count: 1)
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
        allow(FileUtils).to receive(:cp_r).with(anything, %r{\./path/to/output/multi_scan-worker-\d-files})
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
        allow(@mocked_simulator_helper).to receive(:parallel_destination_simulators).and_return(@mocked_cloned_simulators)
      end

      describe '#setup_workers' do
        it 'gets 4 copies of the simulators in the :destination option for :ios_simulator' do
          expect(@mocked_simulator_helper).to receive(:parallel_destination_simulators).and_return(@mocked_cloned_simulators)
          TestBatchWorkerPool.new({parallel_testrun_count: 4, platform: :ios_simulator}).setup_workers
        end

        it 'does not get simulators for :mac' do
          expect(@mocked_simulator_helper).not_to receive(:parallel_destination_simulators)
          TestBatchWorkerPool.new({parallel_testrun_count: 4, platform: :mac}).setup_workers
        end

        describe '#destination_for_worker' do
          it 'creates a :destination array with a string for one simulator for :ios_simulator' do
            pool = TestBatchWorkerPool.new({parallel_testrun_count: 4, platform: :ios_simulator})
            pool.setup_workers
            destination = pool.destination_for_worker(3)
            expect(destination).to eq(["platform=iOS Simulator,id=A00"])
          end
  
          it 'creates a :destination array with two strings for two simulators for :ios_simulator' do
            pool = TestBatchWorkerPool.new({parallel_testrun_count: 4, platform: :ios_simulator})
            pool.setup_workers
            @mocked_cloned_simulators[3] = [
              @mocked_cloned_simulators[2].first,
              @mocked_cloned_simulators[1].first
            ]
            destination = pool.destination_for_worker(3)
            expect(destination).to eq(["platform=iOS Simulator,id=789", "platform=iOS Simulator,id=456"])
          end

          it 'provides the correct :destination for :mac' do
            pool = TestBatchWorkerPool.new({parallel_testrun_count: 4, platform: :mac, destination: ['platform=macOS']})
            destination = pool.destination_for_worker(1)
            expect(destination).to eq(['platform=macOS'])
          end
        end
        
        it 'updates the :buildlog_path for each worker' do
          pool = TestBatchWorkerPool.new(parallel_testrun_count: 4, buildlog_path: './path/to/fake/build/logs')
          expect(pool).to receive(:buildlog_path_for_worker).exactly(4).times
          pool.setup_workers
        end

        it 'updates the :derived_data_path for each worker' do
          pool = TestBatchWorkerPool.new(
            parallel_testrun_count: 4, 
            xctestrun: './path/to/fake/build/products/xctestrun',
            output_directory: './path/to/output'
          )
          allow(pool).to receive(:derived_data_path_for_worker) do |index|
            "./path/to/fake/derived_data_path/#{index + 1}"
          end
          expected_indices = ['1', '2', '3', '4']
          expect(ParallelTestBatchWorker).to receive(:new).exactly(4).times do |options|
            expect(options[:derived_data_path]).to match(%r{path/to/fake/derived_data_path/#{expected_indices.shift}})
          end
          pool.setup_workers
        end

        describe '#clean_up_cloned_simulators' do
          it 'deletes the simulators that were created when the pool is created' do
            pool = TestBatchWorkerPool.new(parallel_testrun_count: 4)
            
            @mocked_cloned_simulators.flatten.each do |simulator|
              expect(simulator).to receive(:delete)
            end
            
            pool.clean_up_cloned_simulators(@mocked_cloned_simulators)
          end
        end

        describe '#setup_cloned_simulators' do
          it 'clones simulators' do
            pool = TestBatchWorkerPool.new({parallel_testrun_count: 4, platform: :ios_simulator})
            expect(@mocked_simulator_helper).to receive(:parallel_destination_simulators).and_return(@mocked_cloned_simulators)
            expect(pool).to receive(:at_exit) do |&block|
              expect(pool).to receive(:clean_up_cloned_simulators)
              block.call()
            end
            pool.setup_cloned_simulators
          end

          it 'cleans up cloned simulators only when exiting from the main process' do
            pool = TestBatchWorkerPool.new({parallel_testrun_count: 4, platform: :ios_simulator})
            expect(@mocked_simulator_helper).to receive(:parallel_destination_simulators).and_return(@mocked_cloned_simulators)
            allow(pool).to receive(:clean_up_cloned_simulators)
            pids = [1, 99]
            allow(Process).to receive(:pid) { pids.shift }
            expect(pool).to receive(:at_exit) do |&block|
              expect(pool).not_to receive(:clean_up_cloned_simulators)
              block.call()
            end
            pool.setup_cloned_simulators
          end
        end

        describe '#buildlog_path_for_worker' do
          it 'creates a subdirectory for each worker in the :buildlog_path' do
            pool = TestBatchWorkerPool.new(
              {
                parallel_testrun_count: 4,
                buildlog_path: './path/to/build/log'
              }
            )
            
            expect(pool.buildlog_path_for_worker(1)).to match(%r{path/to/build/log/worker-2-logs})
          end
        end

        describe '#derived_data_path_for_worker' do
          it 'creates a temporary derived data path for each worker' do
            pool = TestBatchWorkerPool.new(
              {
                parallel_testrun_count: 4,
              }
            )
            allow(Dir).to receive(:mktmpdir).and_return("/tmp/derived_data_path/1")

            expect(pool.derived_data_path_for_worker(1)).to match("/tmp/derived_data_path/1")
          end
        end
      end

      describe '#wait_for_worker' do
        it 'returns 4 ParallelTestBatchWorkers if each has not started working' do
          pool = TestBatchWorkerPool.new(parallel_testrun_count: 4)
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

          pool = TestBatchWorkerPool.new(parallel_testrun_count: 4)
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

      describe '#wait_for_all_workers' do
        it 'waits for all workers and sets their state to :ready_to_work' do
          mocked_workers = [
            OpenStruct.new(state: :working, pid: 1),
            OpenStruct.new(state: :working, pid: 2),
            OpenStruct.new(state: :working, pid: 3),
            OpenStruct.new(state: :working, pid: 4)
          ]
          allow(ParallelTestBatchWorker).to receive(:new) { mocked_workers.shift }
          
          pool = TestBatchWorkerPool.new(
            {
              parallel_testrun_count: 4,
            }
          )
          pool.setup_workers
          
          expect(Process).to receive(:wait).with(1)
          expect(Process).to receive(:wait).with(2)
          expect(Process).to receive(:wait).with(3)
          expect(Process).to receive(:wait).with(4)
          
          mocked_workers.each do |w|
            expect(w).to receive(:process_results)
          end
          expect(pool).to receive(:shutdown_cloned_simulators)

          pool.wait_for_all_workers
        end
      end
    end
  end
end
