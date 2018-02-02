module Fastlane
  module Actions
    class TestsFromXctestrunAction < Action
      def self.run(params)
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Collects all of the tests that are part of the xctestrun file"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :xctestrun,
            env_name: "FL_SUPPRESS_TESTS_FROM_XCTESTRUN_FILE",
            description: "The xctestrun file to use to find where the xctest bundle file is for test retrieval",
            verify_block: proc do |path|
              UI.user_error!("Error: cannot find the xctestrun file '#{path}'") unless File.exist?(path)
            end
          )
        ]
      end

      def self.authors
        ["lyndsey-ferguson/lyndseydf"]
      end

      def self.is_supported?(platform)
        platform == :ios
      end
    end
  end
end
