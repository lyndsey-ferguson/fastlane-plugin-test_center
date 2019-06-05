module TestCenter
  module Helper
    module MultiScanManager
      class ParallelTestBatchWorker < TestBatchWorker
        def run(run_options)
          Process.fork do
            RetryingScan.run(@options.merge(run_options))
          end
        end
      end
    end
  end
end


