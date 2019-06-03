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

        def setup_cloned_simulators
          @simhelper = SimulatorHelper.new(
            parallelize: true,
            batch_count: @options[:parallel_simulator_fork_count] || @options[:batch_count]
          )
          @simhelper.setup
          clones = @simhelper.clone_destination_simulators
          at_exit do
            clean_up_cloned_simulators(clones)
          end
        end

        def destination_from_simulators(simulators)
          simulators.map do |simulator|
            "platform=iOS Simulator,id=#{simulator.udid}"
          end
        end

        def setup_parallel_workers
          clones = setup_cloned_simulators
          desired_worker_count = @options[:parallel_simulator_fork_count]
          @workers = []
          (0...desired_worker_count).each do |index|
            @workers << ParallelTestBatchWorker.new(
              @options.merge(
                destination: destination_from_simulators(clones[index])
              )
            )
          end
        end

        def clean_up_cloned_simulators(clones)
          return if clones.nil?

          clones.flatten.each(&:delete)
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
