module TestCenter
  module Helper
    module MultiScanManager
      class SimulatorHelper
        def initialize(options)
          @options = options
        end

        def setup
          if @options[:parallel_testrun_count] > 1 && @options.fetch(:pre_delete_cloned_simulators, true)
            delete_multi_scan_cloned_simulators
          end
        end

        def clone_destination_simulators
          cloned_simulators = []

          run_count = @options[:parallel_testrun_count] || 0
          original_simulators = FastlaneCore::DeviceManager.simulators('iOS').find_all do |simulator|
            found_match = false
            Scan.config[:destination].each do |destination|
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
            end
            found_match
          end
          original_simulators.each(&:shutdown)
          (0...run_count).each do |batch_index|
            cloned_simulators << []
            original_simulators.each do |simulator|
              FastlaneCore::UI.verbose("Cloning simulator")
              cloned_simulator = simulator.clone
              new_first_name = simulator.name.sub(/( ?\(.*| ?$)/, " Clone #{batch_index + 1}")
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
      end
    end
  end
end
