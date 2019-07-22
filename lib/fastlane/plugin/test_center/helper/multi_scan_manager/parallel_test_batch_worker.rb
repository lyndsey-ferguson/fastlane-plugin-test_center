module TestCenter
  module Helper
    module MultiScanManager
      require 'colorize'

      
      class ParallelTestBatchWorker < TestBatchWorker
        
        attr_reader :pid
        
        def initialize(options)
          super(options)
          @pipe_endpoint = nil

          @@colors ||= String.colors - %i[white black light_green default]
          @color = @@colors.sample
          @@colors = @@colors - [@color]
        end

        def state=(new_state)
          super(new_state)
        end

        def process_results
          # This is performed in the Parent process
          @pid = nil

          worker_prefix = "[worker #{@options[:batch_index] + 1}] "
          File.foreach(@log_filepath) do |line|
            unless FastlaneCore::Helper.colors_disabled?
              worker_prefix = worker_prefix.colorize(@color)
            end
            print worker_prefix
            print line
          end
          state = :ready_to_work

          @options[:test_batch_results] << (@reader.gets.chomp.to_s == 'true')
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
              print_final_results(tests_passed)
              handle_child_process_results(tests_passed)
              exit!
            end
          end
          close_parent_process_writer
        end

        def print_final_results(tests_passed)
          FastlaneCore::UI.verbose("All tests passed for batch #{@options[:batch_index] + 1}? #{tests_passed}")
        end

        def open_interprocess_communication
          # This is performed in the Parent process in preparation to setup
          # the STDOUT and STDOUT for printing messages from the Child process
          # to a file. This is done so that when multiple processes write
          # messages, they will not be written to the console in a broken
          # interlaced manner.
          @reader, @writer = IO.pipe
          @log_filepath = File.join(
            Dir.mktmpdir,
            "parallel-test-batch-#{@options[:batch_index] + 1}.txt"
          )
        end

        def reroute_stdout_to_logfile
          @reader.close # we are now in the subprocess. Write all stdout to the
          # log file to prevent interlaced messages
          @logfile = File.open(@log_filepath, 'w')
          @logfile.sync = true
          $stdout.reopen(@logfile)
          $stderr.reopen(@logfile)
        end

        def handle_child_process_results(tests_passed)
          # as suggested by the method name, this is done in the Child process
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
