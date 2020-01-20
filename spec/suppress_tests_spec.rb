describe Fastlane::Actions::SuppressTestsAction do
  describe 'it handles invalid data' do
    describe 'no project or workspace in the current working directory' do
      it 'a failure occurs when a non-existent project is given' do
        non_existent_project = "lane :test do
          suppress_tests(
            xcodeproj: 'path/to/non_existent_project.xcodeproj',
            tests: [ 'BagOfTests/HappyNapperTests/testBeepingNonExistentFriendDisplaysError', 'GrumpyWorkerTests' ]
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
            tests: [ 'BagOfTests/HappyNapperTests/testBeepingNonExistentFriendDisplaysError', 'GrumpyWorkerTests' ]
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
          suppress_tests(
            xcodeproj: 'path/to/fake_project.xcodeproj',
            scheme: 'HolyGrail',
            tests: [ 'BagOfTests/HappyNapperTests/testBeepingNonExistentFriendDisplaysError', 'BagOfTests/GrumpyWorkerTests' ]
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
        'BagOfTests/@invalidtestsuite1',
        'BagOfTests/#invalidtestsuite1',
        'BagOfTests/3invalidtestsuite1',
        'BagOfTests/validtestsuite/@testInvalid1',
        'BagOfTests/validtestsuite/#testInvalid2',
        'BagOfTests/validtestsuite/3testInvalid',
        'BagOfTests/validtestsuite/test4Invalid()',
        'BagOfTests/validtestsuite.testInvalid',
        'BagOfTests/validtestsuite.testInvalid()', # this is a pattern that people have tried to specify a test
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
              expect(error.message).to match("Error: invalid test identifier '#{invalid_test_identifier}'. It must be in the format of 'Testable/TestSuiteToSuppress' or 'Testable/TestSuiteToSuppress/testToSuppress'")
            end
          )
        end
      end
    end

    describe "a project exists with schemes in the current working directory" do
      include_context "mocked schemes context"

      [
        'BagOfTests/validtestsuite1',
        'BagOfTests/valid2TestSuite',
        'BagOfTests/validtestsuite/testValidEntries1',
        'BagOfTests/validtestsuite/test2ValidEntries'
      ].each do |valid_test_identifier|
        it "no failure occurs when given an valid test: #{valid_test_identifier}" do
          invalid_test_list = "lane :test do
            suppress_tests(
              xcodeproj: 'path/to/fake_project.xcodeproj',
              tests: [ '#{valid_test_identifier}' ]
            )
          end"

          result = Fastlane::FastFile.new.parse(invalid_test_list).runner.execute(:test)
          expect(result).to be_nil
        end
      end

      it 'suppressed tests appear in all Xcode Schemes' do
        fastfile = "lane :test do
          suppress_tests(
            xcodeproj: 'path/to/fake_project.xcodeproj',
            tests: [ 'BagOfTests/HappyNapperTests/testBeepingNonExistentFriendDisplaysError', 'BagOfTests/GrumpyWorkerTests' ]
          )
        end"

        @scheme_skipped_tests.each_key do |scheme|
          xcscheme = @xcschemes[scheme]
          expect(xcscheme).to receive(:save!)
        end
        result = Fastlane::FastFile.new.parse(fastfile).runner.execute(:test)
        expect(@actual_skipped_tests).to include(
          'HappyNapperTests/testBeepingNonExistentFriendDisplaysError',
          'GrumpyWorkerTests'
        )
        expect(result).to be_nil
      end

      it 'suppressed tests appear in the specified Xcode Scheme' do
        fastfile = "lane :test do
          suppress_tests(
            xcodeproj: 'path/to/fake_project.xcodeproj',
            scheme: 'Shared',
            tests: [ 'BagOfTests/HappyNapperTests/testBeepingNonExistentFriendDisplaysError', 'BagOfTests/GrumpyWorkerTests' ]
          )
        end"

        expect(@xcschemes[:everyone]).to receive(:save!)
        expect(@xcschemes[:arthur]).not_to receive(:save!)
        result = Fastlane::FastFile.new.parse(fastfile).runner.execute(:test)
        expect(@actual_skipped_tests).to include(
          'HappyNapperTests/testBeepingNonExistentFriendDisplaysError',
          'GrumpyWorkerTests'
        )
        expect(result).to be_nil
      end

      it 'suppressed tests appear in the specified Xcode Scheme' do
        fastfile = "lane :test do
          suppress_tests(
            workspace: 'path/to/fake_workspace.xcworkspace',
            scheme: 'Shared',
            tests: [ 'BagOfTests/HappyNapperTests/testBeepingNonExistentFriendDisplaysError', 'BagOfTests/GrumpyWorkerTests' ]
          )
        end"

        expect(@xcschemes[:everyone]).to receive(:save!)
        expect(@xcschemes[:arthur]).not_to receive(:save!)
        result = Fastlane::FastFile.new.parse(fastfile).runner.execute(:test)
        expect(@actual_skipped_tests).to include(
          'HappyNapperTests/testBeepingNonExistentFriendDisplaysError',
          'GrumpyWorkerTests'
        )
        expect(result).to be_nil
      end
    end
  end

  describe 'Xcode Scheme with testplans' do
    include_context "mocked schemes context"

    it 'updates the test plan file to remove tests from selected tests' do
      mocked_scheme = OpenStruct.new
      allow(Xcodeproj::XCScheme).to receive(:new).and_return(mocked_scheme)

      mocked_test_action = OpenStruct.new
      allow(mocked_scheme).to receive(:test_action).and_return(mocked_test_action)

      mocked_test_plan = OpenStruct.new
      allow(mocked_test_plan).to receive(:target_referenced_container).and_return('container:Fake.xctestplan')
      mocked_test_plans = [ mocked_test_plan ]
      allow(mocked_test_action).to receive(:test_plans).and_return(mocked_test_plans)


      fastfile = "lane :test do
        suppress_tests(
          workspace: 'path/to/fake_workspace.xcworkspace',
          scheme: 'Shared',
          tests: [ 'FakeUITests/FakeUITests/testExample3' ]
        )
      end"

      allow(File).to receive(:read).with(%r{path/to/Fake.xctestplan}).and_return(File.read('./spec/fixtures/Fake.xctestplan'))
      mocked_writeable_testplan = StringIO.new
      allow(File).to receive(:open).with(%r{path/to/Fake.xctestplan}, 'w').and_yield(mocked_writeable_testplan)
      result = Fastlane::FastFile.new.parse(fastfile).runner.execute(:test)
      testplan = JSON.parse(mocked_writeable_testplan.string)
      expect(testplan['testTargets'][1]['selectedTests']).to eq(['FakeUITests/testExample', 'FakeUITests/testExample2'])
    end
  end
end
