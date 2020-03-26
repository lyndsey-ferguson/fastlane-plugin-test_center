describe Fastlane::Actions::SuppressedTestsAction do
  describe 'it handles invalid data' do
    it 'a failure occurs when a non-existent project is given' do
      non_existent_project = "lane :test do
        suppressed_tests(
          xcodeproj: 'path/to/non_existent_project.xcodeproj'
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
        suppressed_tests(
          xcodeproj: ''
        )
      end"

      expect { Fastlane::FastFile.new.parse(non_existent_project).runner.execute(:test) }.to(
        raise_error(FastlaneCore::Interface::FastlaneError) do |error|
          expect(error.message).to match(/Error: Xcode project file path not given!/)
        end
      )
    end

    it 'a failure occurs when a non-existent Scheme is specified' do
      fastfile = "lane :test do
        suppressed_tests(
          xcodeproj: 'path/to/fake_project.xcodeproj',
          scheme: 'HolyGrail'
        )
      end"
      allow(Dir).to receive(:exist?).with('path/to/fake_project.xcodeproj').and_return(true)
      expect { Fastlane::FastFile.new.parse(fastfile).runner.execute(:test) }.to(
        raise_error(FastlaneCore::Interface::FastlaneError) do |error|
          expect(error.message).to match("Error: cannot find any scheme named HolyGrail")
        end
      )
    end
  end

  describe "a project exists with schemes in the current working directory" do
    include_context "mocked schemes context"

    it "tests are retrieved from all schemes" do
      fastfile = "lane :test do
        suppressed_tests(
          xcodeproj: 'path/to/fake_project.xcodeproj'
        )
      end"

      result = Fastlane::FastFile.new.parse(fastfile).runner.execute(:test)
      expect(result).to eq(
        [
          'BagOfTests/HappyNapperTests/testBeepingNonExistentFriendDisplaysError',
          'BagOfTests/GrumpyWorkerTests',
          'BagOfTests/HappyNapperTests/testClickSoundMadeWhenBucklingUp'
        ]
      )
    end

    it "tests are retrieved from all schemes from the project" do
      fastfile = "lane :test do
        suppressed_tests(
          xcodeproj: 'path/to/fake_project.xcodeproj',
          scheme: 'MesaRedonda'
        )
      end"

      result = Fastlane::FastFile.new.parse(fastfile).runner.execute(:test)
      expect(result).to eq(
        [
          'BagOfTests/HappyNapperTests/testBeepingNonExistentFriendDisplaysError',
          'BagOfTests/GrumpyWorkerTests'
        ]
      )
    end

    it "tests are retrieved from all schemes from the workspace", test_now: true do
      fastfile = "lane :test do
        suppressed_tests(
          workspace: 'path/to/fake_workspace.xcworkspace',
          scheme: 'MesaRedonda'
        )
      end"

      result = Fastlane::FastFile.new.parse(fastfile).runner.execute(:test)
      expect(result).to eq(
        [
          'BagOfTests/HappyNapperTests/testBeepingNonExistentFriendDisplaysError',
          'BagOfTests/GrumpyWorkerTests'
        ]
      )
    end
  end

  describe 'Xcode Scheme with testplans' do
    include_context "mocked schemes context"

    it 'dsiplays a message and returns 0 skipped tests' do
      mocked_scheme = OpenStruct.new
      allow(Xcodeproj::XCScheme).to receive(:new).and_return(mocked_scheme)

      mocked_test_action = OpenStruct.new
      allow(mocked_scheme).to receive(:test_action).and_return(mocked_test_action)

      mocked_test_plans = OpenStruct.new
      allow(mocked_test_action).to receive(:test_plans).and_return(mocked_test_plans)

      expect(FastlaneCore::UI).to receive(:important).with(/Error: unable to read suppressed/)
      fastfile = "lane :test do
        suppressed_tests(
          workspace: 'path/to/fake_workspace.xcworkspace',
          scheme: 'MesaRedonda'
        )
      end"

      result = Fastlane::FastFile.new.parse(fastfile).runner.execute(:test)
      expect(result).to eq([])
    end
  end
end
