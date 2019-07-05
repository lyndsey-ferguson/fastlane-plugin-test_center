module TestCenter
  module Helper
    module MultiScanManager
      class ParallelTestBatchWorker < TestBatchWorker

        attr_reader :pid

        def initialize(options)
          super(options)
          @pipe_endpoint = nil
        end

        def state=(new_state)
          super(new_state)
        end

        def process_results
          @pid = nil
          File.foreach(@log_filepath) do |line|
            puts "[worker #{@options[:batch_index] + 1}] #{line}"
          end
          state = :ready_to_work
          @options[:test_batch_results] << (@reader.gets == 'true')
        end

        def run(run_options)
          self.state = :working

          open_interprocess_communication
          @pid = Process.fork do
            tests_passed = false
            begin
              reroute_stdout_to_logfile
              tests_passed = super(run_options)
            rescue StandardError => e
              puts e.message
              puts e.backtrace.inspect
            ensure
              handle_child_process_results(tests_passed)
              exit!
            end
          end
          close_parent_process_writer
        end

        def open_interprocess_communication
          @reader, @writer = IO.pipe
          @log_filepath = File.join(
            Dir.mktmpdir,
            "parallel-test-batch-#{@options[:batch_index] + 1}.txt"
          )
        end

        def reroute_stdout_to_logfile
          @reader.close # we are now in the subprocess
          @logfile = File.open(@log_filepath, 'w')
          @logfile.sync = true
          $stdout.reopen(@logfile)
          $stderr.reopen(@logfile)
        end

        def handle_child_process_results(tests_passed)
          @logfile.close
          @writer.puts tests_passed.to_s
          @writer.close
        end

        def close_parent_process_writer
          @writer.close
        end
      end
    end
  end
end


