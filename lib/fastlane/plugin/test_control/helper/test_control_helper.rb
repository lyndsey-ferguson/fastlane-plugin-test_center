module Fastlane
  module Helper
    class TestControlHelper
      # class methods that you define here become available in your action
      # as `Helper::TestControlHelper.your_method`
      #
      def self.show_message
        UI.message("Hello from the test_control plugin helper!")
      end
    end
  end
end
