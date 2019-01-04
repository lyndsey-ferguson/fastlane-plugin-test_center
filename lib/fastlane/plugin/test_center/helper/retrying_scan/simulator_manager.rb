module TestCenter
  module Helper
    module RetryingScan
      require 'scan'

      class Parallelization
        def initialize(batch_count, output_directory)
          @batch_count = batch_count
          @output_directory = output_directory
          @simulators ||= []

          if @batch_count < 1
            raise FastlaneCore::FastlaneCrash.new({}), "batch_count (#{@batch_count}) < 1, this should never happen"
          end
          ObjectSpace.define_finalizer(self, self.class.finalize)
        end

        def self.finalize
          proc { cleanup_simulators }
        end

        def setup_simulators(devices, batch_deploymentversions)
          FastlaneCore::DeviceManager.simulators('iOS').each do |simulator|
            simulator.delete if /-batchclone-/ =~ simulator.name
          end

          (0...@batch_count).each do |batch_index|
            found_simulator_devices = []
            if devices.count > 0
              found_simulator_devices = detect_simulator(devices, batch_deploymentversions[batch_index])
            else
              found_simulator_devices = Scan::DetectValues.detect_simulator(devices, 'iOS', 'IPHONEOS_DEPLOYMENT_TARGET', 'iPhone 5s', nil)
            end
            @simulators[batch_index] ||= []
            found_simulator_devices.each do |found_simulator_device|
              device_for_batch = found_simulator_device.clone
              new_name = "#{found_simulator_device.name}-batchclone-#{batch_index + 1}"
              device_for_batch.rename(new_name)
              @simulators[batch_index] << device_for_batch
            end
          end
        end

        def detect_simulator(devices, deployment_target_version)
          require 'set'

          simulators = Scan::DetectValues.filter_simulators(
            FastlaneCore::DeviceManager.simulators('iOS').tap do |array|
              if array.empty?
                FastlaneCore::UI.user_error!(['No', simulator_type_descriptor, 'simulators found on local machine'].reject(&:nil?).join(' '))
              end
            end,
            :greater_than_or_equal,
            deployment_target_version
          ).tap do |sims|
            if sims.empty?
              FastlaneCore::UI.error("No simulators found that are greater than or equal to the version of deployment target (#{deployment_target_version})")
            end
          end

          # At this point we have all simulators for the given deployment target (or higher)

          # We create 2 lambdas, which we iterate over later on
          # If the first lambda `matches` found a simulator to use
          # we'll never call the second one

          matches = lambda do
            set_of_simulators = devices.inject(
              Set.new # of simulators
            ) do |set, device_string|
              pieces = device_string.split(/\s(?=\([\d\.]+\)$)/)

              selector = ->(sim) { pieces.count > 0 && sim.name == pieces.first }

              set + (
                if pieces.count == 0
                  [] # empty array
                elsif pieces.count == 1
                  simulators
                    .select(&selector)
                    .reverse # more efficient, because `simctl` prints higher versions first
                    .sort_by! { |sim| Gem::Version.new(sim.os_version) }
                    .pop(1)
                else # pieces.count == 2 -- mathematically, because of the 'end of line' part of our regular expression
                  version = pieces[1].tr('()', '')
                  potential_emptiness_error = lambda do |sims|
                    if sims.empty?
                      FastlaneCore::UI.error("No simulators found that are equal to the version " \
                      "of specifier (#{version}) and greater than or equal to the version " \
                      "of deployment target (#{deployment_target_version})")
                    end
                  end
                  Scan::DetectValues.filter_simulators(simulators, :equal, version).tap(&potential_emptiness_error).select(&selector)
                end
              ).tap do |array|
                FastlaneCore::UI.error("Ignoring '#{device_string}', couldn't find matching simulator") if array.empty?
              end
            end

            set_of_simulators.to_a
          end

          default = lambda do
            FastlaneCore::UI.error("Couldn't find any matching simulators for '#{devices}' - falling back to default simulator") if (devices || []).count > 0

            result = Array(
              simulators
                .select { |sim| sim.name == default_device_name }
                .reverse # more efficient, because `simctl` prints higher versions first
                .sort_by! { |sim| Gem::Version.new(sim.os_version) }
                .last || simulators.first
            )

            FastlaneCore::UI.message("Found simulator \"#{result.first.name} (#{result.first.os_version})\"") if result.first

            result
          end

          [matches, default].lazy.map { |x|
            arr = x.call
            arr unless arr.empty?
          }.reject(&:nil?).first
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

        def ensure_conflict_free_scanlogging(scan_options, batch_index)
          scan_options[:buildlog_path] = scan_options[:buildlog_path] + "-#{batch_index}"
        end

        def ensure_devices_cloned_for_testrun_are_used(scan_options, batch_index)
          scan_options.delete(:device)
          scan_options[:devices] = devices(batch_index)
        end

        def setup_scan_options_for_testrun(scan_options, batch_index)
          ensure_conflict_free_scanlogging(scan_options, batch_index)
          ensure_devices_cloned_for_testrun_are_used(scan_options, batch_index)
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
          FileUtils.mkdir_p(@output_directory)
          subprocess_output_dir = Dir.mktmpdir
          subprocess_logfilepath = File.join(subprocess_output_dir, "batchscan_#{batch_index}.log")
          $subprocess_logfile = File.open(subprocess_logfilepath, 'w')
          $subprocess_logfile.sync = true
          $old_stdout = $stdout.dup
          $old_stderr = $stderr.dup
          $stdout.reopen($subprocess_logfile)
          $stderr.reopen($subprocess_logfile)
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
          $stdout = $old_stdout.dup
          $stderr = $old_stderr.dup
          _, subprocess_writer = @pipe_endpoints[batch_index]

          subprocess_output = {
            'subprocess_logfilepath' => $subprocess_logfile.path,
            'tests_passed' => result
          }
          subprocess_writer.puts subprocess_output.to_json
          subprocess_writer.flush
          $subprocess_logfile.close
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
