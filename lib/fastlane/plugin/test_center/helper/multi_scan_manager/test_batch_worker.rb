module TestCenter
  module Helper
    module MultiScanManager
      class TestBatchWorker
        attr_accessor :state

        def initialize(options)
          @options = options
          @state = :ready_to_work
        end
        
        def process_results
          @state = :ready_to_work
        end

        def run(run_options)
          self.state = :working
          test_batch_worker_final_result = RetryingScan.run(@options.merge(run_options))
          @options[:test_batch_results] << test_batch_worker_final_result
          self.state = :ready_to_work
          test_batch_worker_final_result
        end
      end
    end
  end
end
