module TestCenter
  module Helper
    module MultiScanManager
      class ParallelTestBatchWorker < TestBatchWorker
        def run(run_options)
          self.state = :working
          Process.fork do
            super(run_options)
          end
        end
      end
    end
  end
end


