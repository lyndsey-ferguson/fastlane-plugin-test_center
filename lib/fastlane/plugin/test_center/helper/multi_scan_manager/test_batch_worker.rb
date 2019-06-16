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
          @options[:test_batch_results] << RetryingScan.run(@options.merge(run_options))
          self.state = :ready_to_work
        end
      end
    end
  end
end
