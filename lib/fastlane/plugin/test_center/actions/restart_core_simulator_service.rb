module Fastlane
  module Actions
    class RestartCoreSimulatorServiceAction < Action
      def self.run(params)
        launchctl_list_count = 0
        while Actions.sh('launchctl list | grep com.apple.CoreSimulator.CoreSimulatorService || true', log: false) != ''
          UI.crash!('Unable to quit com.apple.CoreSimulator.CoreSimulatorService after 10 tries') if (launchctl_list_count += 1) > 10
          commands << Actions.sh('launchctl stop com.apple.CoreSimulator.CoreSimulatorService &> /dev/null || true', log: false)
          UI.verbose('Waiting for com.apple.CoreSimulator.CoreSimulatorService to quit')
          sleep(0.25)
        end
        commands << Actions.sh('launchctl start com.apple.CoreSimulator.CoreSimulatorService &> /dev/null || true', log: false)
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Restarts the com.apple.CoreSimulator.CoreSimulatorService."
      end

      def self.details
        "Sometimes the com.apple.CoreSimulator.CoreSimulatorService can hang. " \
        "Use this action to force-restart it."
      end

      def self.authors
        ["lyndsey-ferguson/@lyndseydf"]
      end

      def self.is_supported?(platform)
        platform == :ios
      end
    end
  end
end
