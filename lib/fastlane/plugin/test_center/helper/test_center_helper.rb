module Fastlane
  module Helper
    class TestCenterHelper
      # class methods that you define here become available in your action
      # as `Helper::TestCenterHelper.your_method`
      #
      def self.show_message
        UI.message("Hello from the test_center plugin helper!")
      end
    end
  end
end
