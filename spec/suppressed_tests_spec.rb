
RSpec.configure do |rspec|
  # This config option will be enabled by default on RSpec 4,
  # but for reasons of backwards compatibility, you have to
  # set it on RSpec 3.
  #
  # It causes the host group and examples to inherit metadata
  # from the shared context.
  rspec.shared_context_metadata_behavior = :apply_to_host_groups
end

RSpec.shared_context "mocked project context", shared_context: :metadata do
  before(:each) do
    allow(Dir).to receive(:exist?).with('path/to/fake_project.xcodeproj').and_return(true)
    @scheme_paths = {
      everyone: 'path/to/fake_project.xcodeproj/xcshareddata/xcschemes/Shared.xcscheme',
      arthur: 'path/to/fake_project.xcodeproj/xcuserdata/auturo/auturo.xcuserdatad/xcschemes/MesaRedonda.xcscheme'
    }
    allow(Dir).to receive(:glob).and_call_original
    allow(Dir).to receive(:glob).with('path/to/fake_project.xcodeproj/{xcshareddata,xcuserdata}/**/xcschemes/*.xcscheme') do
      @scheme_paths.values
    end
    allow(Dir).to receive(:glob).with('path/to/fake_project.xcodeproj/{xcshareddata,xcuserdata}/**/xcschemes/MesaRedonda.xcscheme') do
      [@scheme_paths[:arthur]]
    end
  end
end

RSpec.shared_context "mocked schemes context", shared_context: :metadata do
  include_context "mocked project context"

  before(:each) do
    @xcschemes = {}
    @scheme_paths.each do |scheme, scheme_path|
      xcscheme = OpenStruct.new
      @xcschemes[scheme] = xcscheme
      xcscheme.test_action = OpenStruct.new
      xcscheme.test_action.testables = [
        OpenStruct.new(
          buildable_references: [
            OpenStruct.new(
              buildable_name: 'BagOfTests.xctest'
            )
          ]
        )
      ]
      xcscheme.test_action.testables[0].skipped_tests = [
        OpenStruct.new(identifier: 'HappyNapperTests/testBeepingNonExistentFriendDisplaysError'),
        OpenStruct.new(identifier: 'GrumpyWorkerTests')
      ]
      if scheme == :everyone
        xcscheme.test_action.testables[0].skipped_tests << OpenStruct.new(identifier: 'HappyNapperTests/testClickSoundMadeWhenBucklingUp')
      end
      allow(Xcodeproj::XCScheme).to receive(:new).with(scheme_path).and_return(xcscheme)
    end
  end
end

describe Fastlane::Actions::SuppressedTestsAction, yes: true do
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

    it "tests are retrieved from all schemes" do
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
  end
end
