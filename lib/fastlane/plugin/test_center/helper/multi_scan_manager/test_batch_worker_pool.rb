module TestCenter
  module Helper
    module MultiScanManager
      class TestBatchWorkerPool
        def initialize(options)
          @options = options
        end

        def is_serial?
          @options.fetch(:parallel_testrun_count, 1) == 1
        end

        def setup_workers
          if is_serial?
            setup_serial_workers
          else
            setup_parallel_workers
          end
        end

        def setup_cloned_simulators
          return [] unless @options[:platform] == :ios_simulator

          @simhelper = SimulatorHelper.new(
            parallel_testrun_count: @options[:parallel_testrun_count],
            pre_delete_cloned_simulators: @options.fetch(:pre_delete_cloned_simulators, true),
            reuse_simulators_for_parallel_testruns: @options[:reuse_simulators_for_parallel_testruns] || false
          )
          @simhelper.setup
          @clones = @simhelper.parallel_destination_simulators
          main_pid = Process.pid
          unless @options[:reuse_simulators_for_parallel_testruns]
            at_exit do
              clean_up_cloned_simulators(@clones) if Process.pid == main_pid
            end
          end
          # boot all the simulators _before_ calling `xcodebuilt test` to avoid
          # testmanagerd connection failures.
          @clones.flatten.each(&:shutdown)
          @clones.flatten.each(&:disable_hardware_keyboard)
          @clones.flatten.each(&:boot)
          SimulatorHelper.call_simulator_started_callback(@options, @clones.flatten)
          @clones
        end

        def destination_for_worker(worker_index)
          # each worker has its own simulators to work with
          return @options[:destination] unless @options[:platform] == :ios_simulator

          @clones[worker_index].map do |simulator|
            "platform=iOS Simulator,id=#{simulator.udid}"
          end
        end

        def simulator_devices_for_worker(worker_index)
          return nil unless @options[:platform] == :ios_simulator
          @clones[worker_index]
        end

        def setup_parallel_workers
          setup_cloned_simulators
          desired_worker_count = @options[:parallel_testrun_count]
          @workers = []
          (0...desired_worker_count).each do |worker_index|
            @workers << ParallelTestBatchWorker.new(parallel_scan_options(worker_index))
          end
        end

        def parallel_scan_options(worker_index)
          options = @options.reject { |key| %i[device devices].include?(key) }
          options[:destination] = destination_for_worker(worker_index)
          if @options[:platform] == :ios_simulator
            options[:scan_devices_override] = simulator_devices_for_worker(worker_index)
          end
          options[:buildlog_path] = buildlog_path_for_worker(worker_index) if @options[:buildlog_path]
          options[:derived_data_path] = derived_data_path_for_worker(worker_index)
          options[:batch_index] = worker_index
          options[:test_batch_results] = @options[:test_batch_results]
          options
        end

        def buildlog_path_for_worker(worker_index)
          # ensure that simultaneous simulators are not writing to the same log
          # at the same time.
          "#{@options[:buildlog_path]}/worker-#{worker_index + 1}-logs"
        end

        def derived_data_path_for_worker(worker_index)
          # ensure that simultaneous simulators are not writing diagnostics to
          # the same location at the same time.
          Dir.mktmpdir(['derived_data_path', "-worker-#{(worker_index + 1).to_s}"])
        end

        def clean_up_cloned_simulators(clones)
          return if clones.nil?

          clones.flatten.each(&:delete)
        end

        def shutdown_cloned_simulators(clones)
          return if clones.nil?

          clones.flatten.each(&:shutdown)
        end

        def setup_serial_workers
          serial_scan_options = @options.reject { |key| %i[device devices].include?(key) }
          serial_scan_options[:destination] ||= Scan&.config&.fetch(:destination)
          @workers = [ TestBatchWorker.new(serial_scan_options) ]
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
              worker.process_results
              worker
            end

            first_ready_to_work_worker = @workers.find(if_no_available_workers) do |worker|
              worker.state == :ready_to_work
            end
          end
        end

        def wait_for_all_workers
          unless is_serial?
            busy_workers = @workers.each.select { |w| w.state == :working }
            busy_workers.map(&:pid).each do |pid|
              Process.wait(pid)
            end
            shutdown_cloned_simulators(@clones)
            busy_workers.each { |w| w.process_results }
          end
        end
      end
    end
  end
end
