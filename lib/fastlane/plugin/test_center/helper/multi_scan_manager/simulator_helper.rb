module TestCenter
  module Helper
    module MultiScanManager
      class SimulatorHelper
        def initialize(options)
          @options = options
        end

        def setup
          if (@options[:batch_count] || @options[:parallel_simulator_fork_count] || 1) > 1
            delete_multi_scan_cloned_simulators
          end
        end

        def clone_destination_simulators
          cloned_simulators = []

          batch_count = @options[:batch_count] || @options[:parallel_simulator_fork_count] || 0
          destination_simulator_ids = Scan.config[:destination].map do |destination|
            destination.split(',id=').last
          end
          original_simulators = FastlaneCore::DeviceManager.simulators('iOS').find_all do |simulator|
            destination_simulator_ids.include?(simulator.udid)
          end
          (0...batch_count).each do |batch_index|
            cloned_simulators << []
            original_simulators.each do |simulator|
              FastlaneCore::UI.verbose("Cloning simulator")
              cloned_simulator = simulator.clone
              new_first_name = simulator.name.sub(/( ?\(.*| ?$)/, " Clone #{batch_index}")
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
