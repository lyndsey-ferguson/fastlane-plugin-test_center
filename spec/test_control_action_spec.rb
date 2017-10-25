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
    @scheme_paths = [
      everyone: 'path/to/fake_project.xcodeproj/xcshareddata/xcschemes/Shared.xcscheme',
      arthur: 'path/to/fake_project.xcodeproj/xcuserdata/auturo/auturo.xcuserdatad/xcschemes/MesaRedonda.xcscheme'
    ]
    allow(Dir).to receive(:glob).and_call_original
    allow(Dir).to receive(:glob).with('path/to/fake_project.xcodeproj/{xcshareddata,xcuserdata}/**/xcschemes/*.xcscheme') do
      @scheme_paths.map { |scheme_path_pair| scheme_path_pair[1] }
    end
  end
end

RSpec.shared_context "mocked schemes context", shared_context: :metadata do
  include_context "mocked project context"

  before(:each) do
    @xcschemes = {}
    @scheme_skipped_tests = {}
    @scheme_paths.each do |scheme, scheme_path|
      xcscheme = OpenStruct.new
      @xcschemes[scheme] = xcscheme
      xcscheme.test_action = OpenStruct.new
      xcscheme.test_action.testables = [
        OpenStruct.new
      ]
      skipped_tests = [OpenStruct.new, OpenStruct.new]
      @scheme_skipped_tests[scheme] = skipped_tests.dup # we will change the list below, so make a shallow copy
      allow(Xcodeproj::XCScheme::TestAction::TestableReference::SkippedTest).to receive(:new) do
        skipped_tests.shift
      end
      allow(Xcodeproj::XCScheme).to receive(:new).with(scheme_path).and_return(xcscheme)
    end
  end
end

describe Fastlane::Actions::TestControlAction do
  describe '#run' do
    it 'prints a message' do
      expect(Fastlane::UI).to receive(:message).with("The test_control plugin is working!")

      Fastlane::Actions::TestControlAction.run(nil)
    end

    describe 'it handles invalid data' do
      describe 'no project or workspace in the current working directory' do
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

      describe 'a project exists in the current working directory' do
        it 'a failure occurs when no tests were given to suppress' do
          no_tests = "lane :test do
            suppress_tests(
              xcodeproj: 'path/to/fake_project.xcodeproj',
              tests: [ ]
            )
          end"

          allow(Dir).to receive(:exist?).with('path/to/fake_project.xcodeproj').and_return(true)

          expect { Fastlane::FastFile.new.parse(no_tests).runner.execute(:test) }.to(
            raise_error(FastlaneCore::Interface::FastlaneError) do |error|
              expect(error.message).to match(/Error: no tests were given to suppress!/)
            end
          )
        end

        [
          '', # no test
          '@invalidtestsuite1',
          '#invalidtestsuite1',
          '3invalidtestsuite1',
          'validtestsuite/@testInvalid1',
          'validtestsuite/#testInvalid2',
          'validtestsuite/3testInvalid',
          'validtestsuite/test4Invalid()',
          'validtestsuite.testInvalid',
          'validtestsuite.testInvalid()', # this is a pattern that people have tried to specify a test
        ].each do |invalid_test_identifier|
          it "a failure occurs when given an invalid test: #{invalid_test_identifier}" do
            invalid_test_list = "lane :test do
              suppress_tests(
                xcodeproj: 'path/to/fake_project.xcodeproj',
                tests: [ '#{invalid_test_identifier}' ]
              )
            end"

            allow(Dir).to receive(:exist?).with('path/to/fake_project.xcodeproj').and_return(true)

            expect { Fastlane::FastFile.new.parse(invalid_test_list).runner.execute(:test) }.to(
              raise_error(FastlaneCore::Interface::FastlaneError) do |error|
                expect(error.message).to match("Error: invalid test identifier '#{invalid_test_identifier}'. It must be in the format of 'TestSuiteToSuppress' or 'TestSuiteToSuppress/testToSuppress'")
              end
            )
          end
        end

        [
          'validtestsuite1',
          'valid2TestSuite',
          'validtestsuite/testValidEntries1',
          'validtestsuite/test2ValidEntries'
        ].each do |valid_test_identifier|
          it "no failure occurs when given an valid test: #{valid_test_identifier}" do
            invalid_test_list = "lane :test do
              suppress_tests(
                xcodeproj: 'path/to/fake_project.xcodeproj',
                tests: [ '#{valid_test_identifier}' ]
              )
            end"

            allow(Dir).to receive(:exist?).with('path/to/fake_project.xcodeproj').and_return(true)

            Fastlane::FastFile.new.parse(invalid_test_list).runner.execute(:test)
          end
        end
      end

      describe "a project exists with schemes in the current working directory" do
        include_context "mocked schemes context"

        it 'suppressed tests appear in Xcode Schemes' do
          fastfile = "lane :test do
            suppress_tests(
              xcodeproj: 'path/to/fake_project.xcodeproj',
              tests: [ 'HappyNapperTests/testBeepingNonExistentFriendDisplaysError', 'GrumpyWorkerTests' ]
            )
          end"

          @scheme_skipped_tests.each do |scheme, skipped_tests|
            xcscheme = @xcschemes[scheme]
            testable = xcscheme.test_action.testables[0]
            expect(testable).to receive(:add_skipped_test).with(skipped_tests[0])
            expect(testable).to receive(:add_skipped_test).with(skipped_tests[1])
            expect(skipped_tests[0]).to receive(:identifier=).with('HappyNapperTests/testBeepingNonExistentFriendDisplaysError')
            expect(skipped_tests[1]).to receive(:identifier=).with('GrumpyWorkerTests')
            expect(xcscheme).to receive(:save!)
          end

          Fastlane::FastFile.new.parse(fastfile).runner.execute(:test)
        end
      end
    end
  end
end
