
describe TestCenter do
  describe TestCenter::Helper do
    describe TestCenter::Helper::XcodeJunit do
      before (:each) do
        @report = TestCenter::Helper::XcodeJunit::Report.new('./spec/fixtures/junit.xml')
      end

      it 'can read a file' do
        expect(@report).not_to be(nil)
      end

      it 'provides list of testables' do
        expect(@report.testables).not_to be(nil)
        expect(@report.testables.size).to eq(1)
      end

      describe TestCenter::Helper::XcodeJunit::Testable do
        it 'provides a list of test suites' do
          testable = @report.testables[0]
          expect(testable.testsuites.size).to eq(2)
          expect(testable.name).to eq('BagOfTests.xctest')
        end
      end

      describe TestCenter::Helper::XcodeJunit::TestSuite do
        before (:each) do
          @testsuites = @report.testables[0].testsuites
        end

        it 'has the correct name' do
          expect(@testsuites[0].name).to eq('CoinTossingUITests.CoinTossingUITests')
          expect(@testsuites[1].name).to eq('AtomicBoy')
        end

        it 'detects a Swift testsuite' do
          expect(@testsuites[0].is_swift?).to be(true)
          expect(@testsuites[1].is_swift?).to be(false)
        end
      end

      describe TestCenter::Helper::XcodeJunit::TestCase do
        before (:each) do
          @testcases = []
          @report.testables[0].testsuites.each do |testsuite|
            @testcases.concat(testsuite.testcases)
          end
          @testcases.compact! # remove any nils
        end

        it 'has the correct number of test cases' do
          expect(@testcases.size).to eq(4)
        end

        it 'has the correct name' do
          testcase_names = []
          @testcases.each do |testcase|
            testcase_names << testcase.identifier
          end
          testcase_names.compact!
          expect(testcase_names).to contain_exactly(
            'BagOfTests/CoinTossingUITests/testResultIsHeads',
            'BagOfTests/CoinTossingUITests/testResultIsTails',
            'BagOfTests/AtomicBoy/testRocketBoots',
            'BagOfTests/AtomicBoy/testWristMissles'
          )
        end

        it 'has the correct skipped_tests' do
          actual_skipped_tests = []
          @testcases.each do |testcase|
            actual_skipped_tests << testcase.skipped_test.identifier
          end
          actual_skipped_tests.compact!

          expect(actual_skipped_tests).to contain_exactly(
            'CoinTossingUITests/testResultIsHeads()',
            'CoinTossingUITests/testResultIsTails()',
            'AtomicBoy/testRocketBoots',
            'AtomicBoy/testWristMissles'
          )
        end

        it 'finds the failed tests in skipped_test format' do
          failed_tests = []
          @testcases.each do |testcase|
            failed_tests << testcase.skipped_test.identifier unless testcase.passed?
          end
          failed_tests.compact!

          expect(failed_tests).to contain_exactly(
            'CoinTossingUITests/testResultIsTails()',
            'AtomicBoy/testWristMissles'
          )
        end

        it 'provides the correct failure detail message' do
          failed_test_messages = []
          @testcases.each do |testcase|
            failed_test_messages << testcase.message unless testcase.passed?
          end
          failed_test_messages.compact!

          expect(failed_test_messages).to contain_exactly(
            'XCTAssertEqual failed: ("Heads") is not equal to ("Tails") - ',
            'XCTAssertEqual failed: ("3") is not equal to ("0") - '
          )
        end

        it 'provides the correct failure detail location' do
          failed_test_locations = []
          @testcases.each do |testcase|
            failed_test_locations << testcase.location unless testcase.passed?
          end
          failed_test_locations.compact!

          expect(failed_test_locations).to contain_exactly(
            'CoinTossingUITests.swift:38',
            'AtomicBoy.m:38'
          )
        end
      end
    end
  end
end
