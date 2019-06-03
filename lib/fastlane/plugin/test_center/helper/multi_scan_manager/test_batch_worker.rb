module TestCenter
  module Helper
    module MultiScanManager
      class TestBatchWorker
        def initialize(options)
          @options = options
        end

        def state
          :ready_to_work
        end

        def run(run_options)
          RetryingScan.run(@options.merge(run_options))
        end
      end
    end
  end
end
