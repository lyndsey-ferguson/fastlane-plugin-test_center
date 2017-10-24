describe Fastlane::Actions::TestCenterAction do
  describe '#run' do
    it 'prints a message' do
      expect(Fastlane::UI).to receive(:message).with("The test_center plugin is working!")

      Fastlane::Actions::TestCenterAction.run(nil)
    end
  end
end
