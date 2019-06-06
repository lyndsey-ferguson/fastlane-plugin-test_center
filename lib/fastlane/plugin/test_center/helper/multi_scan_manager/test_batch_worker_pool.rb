module TestCenter
  module Helper
    module MultiScanManager
      class TestBatchWorkerPool
        def initialize(options)
          @options = options
        end

        def is_serial?
          @options.fetch(:parallel_simulator_fork_count, 1) == 1
        end

        def setup_workers
          if is_serial?
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
          (0...desired_worker_count).each do |worker_index|
            parallel_scan_options = @options.clone
            parallel_scan_options[:destination] = destination_from_simulators(clones[worker_index])
            if @options[:xctestrun]
              parallel_scan_options[:xctestrun] = clone_temporary_xcbuild_products_dir
            end
            if @options[:xctestrun]
              parallel_scan_options[:buildlog_path] = buildlog_path_for_worker(worker_index)
            end
            parallel_scan_options[:derived_data_dir] = derived_data_path_for_worker(worker_index)
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

        def buildlog_path_for_worker(worker_index)
          "#{@options[:buildlog_path]}/parallel-simulators-#{worker_index}-logs"
        end

        def derived_data_path_for_worker(worker_index)
          Dir.mktmpdir(['derived_data_dir', "-worker-#{worker_index.to_s}"])
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

        def wait_for_worker
          if is_serial?
            return @workers[0]
          else
            if_no_available_workers = Proc.new do
              worker = nil
              loop do
                freed_child_proc_pid = Process.wait
                worker = @workers.find do |w|
                  w.pid == freed_child_proc_pid
                end

                break if worker
              end
              # worker.clean_up_or_whatever
              # TODO: do not set state directly
              worker.state == :ready_to_work
              worker
            end

            first_ready_to_work_worker = @workers.find(if_no_available_workers) do |worker|
              worker.state == :ready_to_work
            end
          end
        end

        def wait_for_all_workers
          unless is_serial?
          end
        end
      end
    end
  end
end
