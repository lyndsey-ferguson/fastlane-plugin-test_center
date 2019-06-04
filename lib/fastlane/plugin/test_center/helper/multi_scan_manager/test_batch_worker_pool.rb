module TestCenter
  module Helper
    module MultiScanManager
      class TestBatchWorkerPool
        def initialize(options)
          @options = options
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
            parallel_scan_options = @options.clone
            parallel_scan_options[:destination] = destination_from_simulators(clones[index])
            if @options[:xctestrun]
              parallel_scan_options[:xctestrun] = clone_temporary_xcbuild_products_dir
            end
            @workers << ParallelTestBatchWorker.new(parallel_scan_options)
          end
        end

        def clone_temporary_xcbuild_products_dir
          xctestrun_filename = File.basename(@options[:xctestrun])
          xcproduct_dirpath = File.dirname(@options[:xctestrun])
          tmp_xcproduct_dirpath = Dir.mktmpdir

          FileUtils.copy_entry(xcproduct_dirpath, tmp_xcproduct_dirpath)
          at_exit do
            FileUtils.rm_rf(tmp_xcproduct_dirpath)
          end
          tmp_xcproduct_dirpath
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
