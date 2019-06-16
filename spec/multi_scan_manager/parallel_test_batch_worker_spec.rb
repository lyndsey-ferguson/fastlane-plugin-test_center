module TestCenter::Helper::MultiScanManager
  describe 'ParallelTestBatchWorker' do
    describe '#run' do
      before(:each) do
        allow_any_instance_of(ParallelTestBatchWorker).to receive(:open_interprocess_communication)
        allow_any_instance_of(ParallelTestBatchWorker).to receive(:close_parent_process_writer)
        allow_any_instance_of(ParallelTestBatchWorker).to receive(:reroute_stdout_to_logfile)
        allow_any_instance_of(ParallelTestBatchWorker).to receive(:handle_child_process_results)
      end

      it 'calls the parent class\'s #run method in a fork block' do
        worker = ParallelTestBatchWorker.new({ test_batch_results: [] })
        expect(worker).to receive(:exit!)
        expect(worker).to receive(:open_interprocess_communication)
        expect(Process).to receive(:fork) do |&block|
          expect(RetryingScan).to receive(:run)
          block.call()
        end
        expect(worker).to receive(:close_parent_process_writer)
        worker.run({})
      end

      it 'sets :state to working' do
        worker = ParallelTestBatchWorker.new({ test_batch_results: [] })
        allow(Process).to receive(:fork)
        states = [ worker.state ]
        allow(worker).to receive(:state=) { |new_state| states << new_state }
        worker.run({})
        expect(states).to eq(
          %i[ready_to_work working]
        )
      end

      it 'updates :pid when forking' do
        worker = ParallelTestBatchWorker.new({ test_batch_results: [] })
        allow(Process).to receive(:fork).and_return(11)
        worker.run({})
        expect(worker.pid).to eq(11)
      end
    end

    describe '#process_results' do
      it 'resets :pid when done' do
        worker = ParallelTestBatchWorker.new({ test_batch_results: [] })
        allow(Process).to receive(:fork).and_return(11)
        allow(File).to receive(:foreach).and_yield('')
        worker.run({})
        worker.process_results
        expect(worker.pid).to be_nil
      end
    end

    describe '#reroute_stdout_to_logfile' do
      it 'properly sets up STDOUT STDERR to print to the logfile' do
        worker = ParallelTestBatchWorker.new({ test_batch_results: [], batch_index: 5 })
        pipes = [
          OpenStruct.new,
          OpenStruct.new
        ]
        
        allow(IO).to receive(:pipe).and_return(pipes)
        allow(Dir).to receive(:mktmpdir).and_return('path/to/tmpfile')
        worker.open_interprocess_communication
        
        mock_logfile = OpenStruct.new
        expect(File).to receive(:open).with('path/to/tmpfile/parallel-test-batch-5.txt', 'w').and_return(mock_logfile)
        expect(pipes[0]).to receive(:close)

        expect($stdout).to receive(:reopen).with(mock_logfile)
        expect($stderr).to receive(:reopen).with(mock_logfile)
        worker.reroute_stdout_to_logfile
      end

      it 'properly prints out the results when completed' do
        worker = ParallelTestBatchWorker.new({ test_batch_results: [], batch_index: 5 })
        mock_writer = StringIO.new

        mock_logfile = OpenStruct.new
        worker.instance_variable_set(:@logfile, mock_logfile)
        worker.instance_variable_set(:@writer, mock_writer)

        expect(mock_logfile).to receive(:close)
        expect(mock_writer).to receive(:puts).with('false')
        expect(mock_writer).to receive(:close)
        worker.handle_child_process_results(false)
      end
    end
  end
end
