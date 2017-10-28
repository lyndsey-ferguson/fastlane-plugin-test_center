module Fastlane
  module Actions
    class TestCenterAction < Action
      def self.run(params)
        UI.message("The test_center plugin is working!")
      end

      def self.description
        "Makes testing your iOS app easier"
      end

      def self.authors
        ["Lyndsey Ferguson"]
      end

      def self.return_value
        # If your method provides a return value, you can describe here what it does
      end

      def self.details
        # Optional:
        "Makes testing your iOS app easier by providing a list of possible tests, changing what tests are suppressed or not, re-running fragile tests, etc."
      end

      def self.available_options
        [
          # FastlaneCore::ConfigItem.new(key: :your_option,
          #                         env_name: "TEST_CENTER_YOUR_OPTION",
          #                      description: "A description of your option",
          #                         optional: false,
          #                             type: String)
        ]
      end

      def self.is_supported?(platform)
        # Adjust this if your plugin only works for a particular platform (iOS vs. Android, for example)
        # See: https://github.com/fastlane/fastlane/blob/master/fastlane/docs/Platforms.md
        #
        # [:ios, :mac, :android].include?(platform)
        true
      end
    end
  end
end
