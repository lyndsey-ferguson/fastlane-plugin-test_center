module Fastlane
  module Actions
    class QuitCoreSimulatorServiceAction < Action
      def self.run(params)
        launchctl_list_count = 0
        commands = []
        while Actions.sh('launchctl list | grep com.apple.CoreSimulator.CoreSimulatorService || true', log: false) != ''
          UI.crash!('Unable to quit com.apple.CoreSimulator.CoreSimulatorService after 10 tries') if (launchctl_list_count += 1) > 10
          commands << Actions.sh('launchctl remove com.apple.CoreSimulator.CoreSimulatorService &> /dev/null || true', log: false)
          UI.verbose('Waiting for com.apple.CoreSimulator.CoreSimulatorService to quit')
          sleep(0.5)
        end
        commands
      end

      #####################################################
      # @!group Documentation
      #####################################################

      # :nocov:
      def self.description
        "📲 Force-quits the com.apple.CoreSimulator.CoreSimulatorService to fix mysterious iOS Simulator issues."
      end

      def self.details
        "Sometimes the com.apple.CoreSimulator.CoreSimulatorService can hang. " \
        "Use this action to force-quit it."
      end

      def self.authors
        ["lyndsey-ferguson/@lyndseydf"]
      end

      def self.category
        :testing
      end

      def self.is_supported?(platform)
        platform == :ios
      end
      # :nocov:
    end
  end
end
