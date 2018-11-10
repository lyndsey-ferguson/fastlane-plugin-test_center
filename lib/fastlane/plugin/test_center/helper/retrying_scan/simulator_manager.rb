module TestCenter
  module Helper
    module RetryingScan
      require 'scan'

      class Parallelization
        def initialize(batch_count)
          @batch_count = batch_count

          @simulators ||= []

          if @batch_count < 1
            raise FastlaneCore::FastlaneCrash.new({}), "batch_count (#{@batch_count}) < 1, this should never happen"
          end
          ObjectSpace.define_finalizer(self, self.class.finalize)
        end

        def self.finalize
          proc { cleanup_simulators }
        end

        def setup_simulators(devices)
          found_simulator_devices = []
          FastlaneCore::DeviceManager.simulators('iOS').each do |simulator|
            simulator.delete if /-batchclone-/ =~ simulator.name
          end

          if devices.count > 0
            found_simulator_devices = Scan::DetectValues.detect_simulator(devices, '', '', '', nil)
          else
            found_simulator_devices = Scan::DetectValues.detect_simulator(devices, 'iOS', 'IPHONEOS_DEPLOYMENT_TARGET', 'iPhone 5s', nil)
          end
          (0...@batch_count).each do |batch_index|
            @simulators[batch_index] ||= []
            found_simulator_devices.each do |found_simulator_device|
              device_for_batch = found_simulator_device.clone
              new_name = "#{found_simulator_device.name}-batchclone-#{batch_index + 1}"
              device_for_batch.rename(new_name)
              @simulators[batch_index] << device_for_batch
            end
          end
        end

        def cleanup_simulators
          @simulators.flatten.each(&:delete)
          @simulators = []
        end

        def devices(batch_index)
          if batch_index > @batch_count
            simulator_count = [@batch_count, @simulators.count].max
            raise "Error: impossible to request devices for batch #{batch_index}, there are only #{simulator_count} set(s) of simulators"
          end

          if @simulators.count > 0
            @simulators[batch_index - 1].map do |simulator|
              "#{simulator.name} (#{simulator.os_version})"
            end
          else
            @scan_options[:devices] || Array(@scan_options[:device])
          end
        end

        def setup_pipes_for_fork
          @pipe_endpoints = []
          (0...@batch_count).each do
            @pipe_endpoints << IO.pipe
          end
        end

        def connect_subprocess_endpoint(batch_index)
          mainprocess_reader, = @pipe_endpoints[batch_index]
          mainprocess_reader.close # we are now in the subprocess

          subprocess_output_dir = Dir.mktmpdir
          puts "log files written to #{subprocess_output_dir}"
          subprocess_logfilepath = File.join(subprocess_output_dir, "batchscan_#{batch_index}.log")
          subprocess_logfile = File.open(subprocess_logfilepath, 'w')
          $stdout.reopen(subprocess_logfile)
          $stderr.reopen(subprocess_logfile)
        end

        def disconnect_subprocess_endpoints
          # This is done from the parent process to close the pipe from its end so
          # that its reading of the pipe doesn't block waiting for more IO on the
          # writer.
          # This has to be done after the fork, because we don't want the subprocess
          # to receive its endpoint already closed.
          @pipe_endpoints.each { |_, subprocess_writer| subprocess_writer.close }
        end

        def send_subprocess_result(batch_index, result)
          _, subprocess_writer = @pipe_endpoints[batch_index]
          subprocess_logfile = $stdout # Remember? We changed $stdout in :connect_subprocess_endpoint to be a File.

          subprocess_output = {
            'subprocess_logfilepath' => subprocess_logfile.path,
            'tests_passed' => result
          }
          subprocess_writer.puts subprocess_output.to_json
          subprocess_writer.flush
          subprocess_logfile.close
        end

        def parse_subprocess_results(subprocess_index, subprocess_output)
          subprocess_result = {
            'tests_passed' => false
          }
          if subprocess_output.empty?
            FastlaneCore::UI.error("Something went terribly wrong: no output from parallelized batch #{subprocess_index}!")
          else
            subprocess_result = JSON.parse(subprocess_output)
          end
          subprocess_result
        end

        def stream_subprocess_result_to_console(subprocess_logfilepath)
          puts '-' * 80
          if File.exist?(subprocess_logfilepath)
            File.foreach(subprocess_logfilepath, "r:UTF-8") do |line|
              puts line
            end
          end
        end

        def wait_for_subprocesses
          disconnect_subprocess_endpoints # to ensure no blocking on the pipe
          FastlaneCore::Helper.show_loading_indicator("Scanning in #{@batch_count} batches")
          Process.waitall
          FastlaneCore::Helper.hide_loading_indicator
        end

        def handle_subprocesses_results
          tests_passed = false
          FastlaneCore::UI.header("Output from parallelized batch run")
          @pipe_endpoints.each_with_index do |endpoints, index|
            mainprocess_reader, = endpoints
            subprocess_result = parse_subprocess_results(index, mainprocess_reader.read)
            mainprocess_reader.close
            stream_subprocess_result_to_console(subprocess_result['subprocess_logfilepath'])
            tests_passed = subprocess_result['tests_passed']
          end
          puts '=' * 80
          tests_passed
        end
      end
    end
  end
end

module FastlaneCore
  class DeviceManager
    class Device
      def clone
        raise 'Can only clone iOS Simulators' unless self.is_simulator

        Device.new(
          name: self.name,
          udid: `xcrun simctl clone #{self.udid} '#{self.name}'`.chomp,
          os_type: self.os_type,
          os_version: self.os_version,
          state: self.state,
          is_simulator: self.is_simulator
        )
      end

      def rename(newname)
        `xcrun simctl rename #{self.udid} '#{newname}'`
        self.name = newname
      end
    end
  end
end
