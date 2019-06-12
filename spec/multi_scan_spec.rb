require 'scan'

module Fastlane::Actions
  describe 'MultiScanAction' do
    describe '#prepare_for_testing' do
      it 'builds the app if is not there yet' do
        expect(MultiScanAction).to receive(:prepare_scan_config)
        MultiScanAction.prepare_for_testing(
          {
            test_without_building: true,
            skip_build: true 
          }
        )
      end

      it 'sets up the Scan.config' do
        expect(MultiScanAction).to receive(:prepare_scan_config)
        MultiScanAction.prepare_for_testing(
          {
            test_without_building: true,
            skip_build: true 
          }
        )
      end
    end

    describe '#run_summary' do
      it 'provides a sensible run_summary for 1 retry' do
        allow(Dir).to receive(:glob)
          .with('test_output/**/report*.xml')
          .and_return([File.absolute_path('./spec/fixtures/junit.xml')])
        
        other_action_mock = OpenStruct.new
        allow(MultiScanAction).to receive(:other_action).and_return(other_action_mock)
        allow(other_action_mock).to receive(:tests_from_junit).and_return(
          {
            passing: [ '1', '2' ],
            failed: [
              'BagOfTests/CoinTossingUITests/testResultIsTails',
              'BagOfTests/AtomicBoy/testWristMissles'
            ],
            failure_details: {
              'BagOfTests/CoinTossingUITests/testResultIsTails' => {
                message: 'XCTAssertEqual failed: ("Heads") is not equal to ("Tails") - ',
                location: 'CoinTossingUITests.swift:38'
              },
              'BagOfTests/AtomicBoy/testWristMissles' => {
                message: 'XCTAssertEqual failed: ("3") is not equal to ("0") - ',
                location: 'AtomicBoy.m:38'
              }
            }
          }
        )
        summary = MultiScanAction.run_summary(
          {
            output_types: 'junit',
            output_files: 'report.xml',
            output_directory: 'test_output'
          },
          true,
          1
        )
        expect(summary).to include(
          result: true,
          total_tests: 4,
          passing_testcount: 2,
          failed_testcount: 2,
          failed_tests: [
            'BagOfTests/CoinTossingUITests/testResultIsTails',
            'BagOfTests/AtomicBoy/testWristMissles'
          ],
          failure_details: {
            'BagOfTests/CoinTossingUITests/testResultIsTails' => {
              message: 'XCTAssertEqual failed: ("Heads") is not equal to ("Tails") - ',
              location: 'CoinTossingUITests.swift:38'
            },
            'BagOfTests/AtomicBoy/testWristMissles' => {
              message: 'XCTAssertEqual failed: ("3") is not equal to ("0") - ',
              location: 'AtomicBoy.m:38'
            }
          },
          total_retry_count: 1
        )
        expect(summary[:report_files][0]).to match(%r{.*/spec/fixtures/junit.xml})
      end

      it 'provides a sensible run_summary for 2 retries' do
        allow(Dir).to receive(:glob)
          .with('test_output/**/report*.xml')
          .and_return([File.absolute_path('./spec/fixtures/junit.xml')])
        
        other_action_mock = OpenStruct.new
        allow(MultiScanAction).to receive(:other_action).and_return(other_action_mock)
        allow(other_action_mock).to receive(:tests_from_junit).and_return(
          {
            passing: [ '1', '2', '3', '4' ],
            failed: [
              'BagOfTests/CoinTossingUITests/testResultIsTails',
              'BagOfTests/AtomicBoy/testWristMissles',
              'BagOfTests/CoinTossingUITests/testResultIsTails',
              'BagOfTests/AtomicBoy/testWristMissles'
            ],
            failure_details: {
              'BagOfTests/CoinTossingUITests/testResultIsTails' => {
                message: 'XCTAssertEqual failed: ("Heads") is not equal to ("Tails") - ',
                location: 'CoinTossingUITests.swift:38'
              },
              'BagOfTests/AtomicBoy/testWristMissles' => {
                message: 'XCTAssertEqual failed: ("3") is not equal to ("0") - ',
                location: 'AtomicBoy.m:38'
              }
            },
            report_files: [
              "/Users/lyndsey.ferguson/repo/fastlane-plugin-test_center/spec/fixtures/junit.xml"
            ]
          }
        )
        summary = MultiScanAction.run_summary(
          {
            output_types: 'junit',
            output_files: 'report.xml',
            output_directory: 'test_output'
          },
          false,
          2
        )
        expect(summary).to include(
          result: false,
          total_tests: 8,
          passing_testcount: 4,
          failed_testcount: 4,
          failed_tests: [
            'BagOfTests/CoinTossingUITests/testResultIsTails',
            'BagOfTests/AtomicBoy/testWristMissles',
            'BagOfTests/CoinTossingUITests/testResultIsTails',
            'BagOfTests/AtomicBoy/testWristMissles'
          ],
          failure_details: {
            'BagOfTests/CoinTossingUITests/testResultIsTails' => {
              message: 'XCTAssertEqual failed: ("Heads") is not equal to ("Tails") - ',
              location: 'CoinTossingUITests.swift:38'
            },
            'BagOfTests/AtomicBoy/testWristMissles' => {
              message: 'XCTAssertEqual failed: ("3") is not equal to ("0") - ',
              location: 'AtomicBoy.m:38'
            }
          },
          total_retry_count: 2
        )
      end
    end

    describe '#run' do
      it 'returns the result when nothing catastrophic goes on' do
        mocked_runner = OpenStruct.new
        allow(mocked_runner).to receive(:run).and_return(false)
        allow(::TestCenter::Helper::MultiScanManager::Runner).to receive(:new).and_return(mocked_runner)
        run_summary_mock = { this_to_shall_pass: true }
        expect(MultiScanAction).to receive(:run_summary).and_return(run_summary_mock)
        expect(MultiScanAction).to receive(:prepare_for_testing)
        
        options_mock = {
          try_count: 1
        }
        allow(options_mock).to receive(:_values).and_return(options_mock)
        summary = MultiScanAction.run(options_mock)
        expect(summary).to eq(run_summary_mock)
      end

      it 'raises an exception when :fail_build is set to true and tests fail' do
        mocked_runner = OpenStruct.new
        allow(mocked_runner).to receive(:run).and_return(true)
        allow(::TestCenter::Helper::MultiScanManager::Runner).to receive(:new).and_return(mocked_runner)
        run_summary_mock = { this_to_shall_pass: true }
        expect(MultiScanAction).to receive(:run_summary).and_return(run_summary_mock)
        expect(MultiScanAction).to receive(:prepare_for_testing)
        
        options_mock = {
          try_count: 1
        }
        allow(options_mock).to receive(:_values).and_return(options_mock)
        summary = MultiScanAction.run(options_mock)
        expect(summary).to eq(run_summary_mock)
      end
    end

    it 'Doesnt run when batch_count and invocation_based_tests are set' do
      invocation_based_project = "lane :test do
        multi_scan(
          workspace: File.absolute_path('../KiwiDemo/KiwiDemo.xcworkspace'),
          scheme: 'KiwiDemoTests',
          try_count: 2,
          invocation_based_tests: true,
          batch_count: 2
        )
      end"
  
      expect { Fastlane::FastFile.new.parse(invocation_based_project).runner.execute(:test) }.to(
        raise_error(FastlaneCore::Interface::FastlaneError) do |error|
          expect(error.message).to match(
            "Error: Can't use 'invocation_based_tests' and 'batch_count' options in one run, "\
            "because the number of tests is unkown."
          )
        end
      )
    end
  end

end
