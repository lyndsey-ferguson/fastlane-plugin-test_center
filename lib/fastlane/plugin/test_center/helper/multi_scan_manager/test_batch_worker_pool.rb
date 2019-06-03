module TestCenter
  module Helper
    module MultiScanManager
      class TestBatchWorkerPool
        def initialize(options)
          @options = options
          setup_workers
        end

        def setup_workers
          if @options.fetch(:parallel_simulator_fork_count, 1) == 1
            setup_serial_workers
          else
            setup_parallel_workers
          end
        end

        def setup_parallel_workers
          @simhelper = SimulatorHelper.new(
            parallelize: true,
            batch_count: @options[:batch_count]
          )
          @simhelper.setup
          @simhelper.clone_destination_simulators
          desired_worker_count = @options[:parallel_simulator_fork_count]
          @workers = []
          (0...desired_worker_count).each do
            @workers << ParallelTestBatchWorker.new(@options)
          end
        end

        def setup_serial_workers
          @workers = [
            TestBatchWorker.new(@options)
          ]
        end

        def available_workers
          @workers
        end
      end
    end
  end
end
