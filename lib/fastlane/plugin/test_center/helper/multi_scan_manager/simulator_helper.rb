module TestCenter
  module Helper
    module MultiScanManager
      class SimulatorHelper
        def initialize(options)
          @options = options
          # TODO: add byebug to make sure we're mocking this
          @all_simulators = FastlaneCore::DeviceManager.simulators('iOS') 
        end

        def setup
          if @options[:parallel_testrun_count] > 1 && @options.fetch(:pre_delete_cloned_simulators, true)
            delete_multi_scan_cloned_simulators
          end
        end

        def parallel_destination_simulators
          remaining_desired_simulators = @options[:parallel_testrun_count] || 0

          simulators = []
          if @options[:reuse_simulators_for_parallel_testruns]
            matching_simulators = find_matching_destination_simulators(remaining_desired_simulators)
            remaining_desired_simulators -= matching_simulators.size
            (0...matching_simulators.size).each do |s|
              simulators << [matching_simulators[s]]
            end
          end

          if remaining_desired_simulators > 0
            simulators.concat(clone_destination_simulators(remaining_desired_simulators))
          end
          simulators
        end

        def find_matching_destination_simulators(remaining_desired_simulators)
          destination = Scan.config[:destination].clone.first

          desired_device = @all_simulators.find do |simulator|
            match = destination.match(/id=(?<udid>[^,]+)/) 
            match && match[:udid] == simulator.udid
          end

          matching_simulators = @all_simulators.find_all do |simulator|
            desired_device.os_version == simulator.os_version && simulator.name =~ /#{Regexp.escape(desired_device.name)} Clone \d #{self.class.name}<[^>]+>/ 
          end
          matching_simulators.first(remaining_desired_simulators)
        end

        def simulator_matches_destination(simulator, destination)
          match = destination.match(/id=(?<udid>[^,]+)/)
          if match
            found_match = (match[:udid] == simulator.udid)
          else
            match = destination.match(/name=(?<name>[^,]+)/)
            name = match[:name] || ''
            match = destination.match(/OS=(?<os_version>[^,]+)/)
            os_version = match[:os_version] || ''

            found_match = (name == simulator.name && os_version == simulator.os_version)
          end
          found_match
        end

        def clone_destination_simulators(remaining_desired_simulators)
          cloned_simulators = []

          run_count = remaining_desired_simulators
          destinations = Scan.config[:destination].clone
          original_simulators = @all_simulators.find_all do |simulator|
            found_simulator = destinations.find do |destination|
              simulator_matches_destination(simulator, destination)
            end
            if found_simulator
              destinations.delete(found_simulator)
            end

            !found_simulator.nil?
          end
          original_simulators.each(&:shutdown)
          (0...run_count).each do |batch_index|
            cloned_simulators << []
            original_simulators.each do |simulator|
              cloned_simulator = simulator.clone
              new_first_name = simulator.name.sub(/( ?\(.*| ?$)/, " Clone #{batch_index + 1}")
              FastlaneCore::UI.verbose("Cloned simulator #{simulator.name} to (name=#{new_first_name}, udid=#{cloned_simulator.udid}, OS=#{cloned_simulator.ios_version})")
              new_last_name = "#{self.class.name}<#{self.object_id}>"
              cloned_simulator.rename("#{new_first_name} #{new_last_name}")

              cloned_simulators.last << cloned_simulator
            end
          end
          cloned_simulators
        end

        def delete_multi_scan_cloned_simulators
          FastlaneCore::DeviceManager.simulators('iOS').each do |simulator|
            simulator.delete if /#{self.class.name}<\d+>/ =~ simulator.name
          end
        end

        def self.call_simulator_started_callback(options, devices)
          return unless options[:simulator_started_callback]
          return unless options[:platform] == :ios_simulator

          devices.each do |device|
            options[:simulator_started_callback].call(device.udid)
          end
        end
      end
    end
  end
end
