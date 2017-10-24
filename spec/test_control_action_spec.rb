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
    end
  end
end
