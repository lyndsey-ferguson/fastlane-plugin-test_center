describe Fastlane::Actions::TestControlAction do
  describe '#run' do
    it 'prints a message' do
      expect(Fastlane::UI).to receive(:message).with("The test_control plugin is working!")

      Fastlane::Actions::TestControlAction.run(nil)
    end
  end
end
