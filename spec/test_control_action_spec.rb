describe Fastlane::Actions::TestControlAction do
  describe '#run' do
    it 'prints a message' do
      expect(Fastlane::UI).to receive(:message).with("The test_control plugin is working!")

      Fastlane::Actions::TestControlAction.run(nil)
    end

    it 'a failure occurs when a non-existent project is given' do
      non_existent_project = "lane :test do
        suppress_tests(
          xcodeproj: 'path/to/non_existent_project.xcodeproj',
          tests: [ 'HappyNapperTests/testBeepingNonExistentFriendDisplaysError', 'GrumpyWorkerTests' ]
        )
      end"

      expect { Fastlane::FastFile.new.parse(non_existent_project).runner.execute(:test) }.to(
        raise_error(FastlaneCore::Interface::FastlaneError) do |error|
          expect(error.message).to match(%r{Error: Xcode project 'path/to/non_existent_project.xcodeproj' not found!})
        end
      )
    end

    it 'a failure occurs when a no project is given' do
      non_existent_project = "lane :test do
        suppress_tests(
          xcodeproj: '',
          tests: [ 'HappyNapperTests/testBeepingNonExistentFriendDisplaysError', 'GrumpyWorkerTests' ]
        )
      end"

      expect { Fastlane::FastFile.new.parse(non_existent_project).runner.execute(:test) }.to(
        raise_error(FastlaneCore::Interface::FastlaneError) do |error|
          expect(error.message).to match(/Error: Xcode project file path not given!/)
        end
      )
    end
  end
end
