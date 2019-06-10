module TestCenter
  module Helper
    module MultiScanManager
      class ParallelTestBatchWorker < TestBatchWorker
        attr_reader :pid

        def state=(new_state)
          super(new_state)
          @pid = nil unless new_state == :working
        end

        def run(run_options)
          self.state = :working
          @pid = Process.fork do
            begin
              super(run_options)
            ensure
              exit!
            end
          end
        end
      end
    end
  end
end


