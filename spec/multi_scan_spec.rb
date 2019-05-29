require 'scan'

describe Fastlane::Actions::MultiScanAction do
  before(:each) do
  end
  # FastlaneCore::UI

  it 'the project is built if not given :test_without_building' do
    non_existent_project = "lane :test do
      multi_scan(
        project: File.absolute_path('../AtomicBoy/AtomicBoy.xcodeproj'),
        scheme: 'AtomicBoy',
        try_count: 2,
        output_directory: 'path/to',
        fail_build: false
      )
    end"
    expect(Scan).to receive(:config).and_return({ derived_data_path: '.' })
    expect(Fastlane::Actions::ScanAction).to receive(:run)

    mocked_scanner = OpenStruct.new
    allow(::TestCenter::Helper::CorrectingScanHelper).to receive(:new).and_return(mocked_scanner)
    expect(mocked_scanner).to receive(:scan).and_return(true)
    expect(Fastlane::Actions::MultiScanAction).to receive(:run_summary)
    Fastlane::FastFile.new.parse(non_existent_project).runner.execute(:test)
  end

  it 'the project is not built if given :skip_build true and _not_ given :test_without_building' do
    non_existent_project = "lane :test do
      multi_scan(
        project: File.absolute_path('../AtomicBoy/AtomicBoy.xcodeproj'),
        scheme: 'AtomicBoy',
        try_count: 2,
        output_directory: 'path/to',
        fail_build: false,
        skip_build: true
      )
    end"
    expect(Fastlane::Actions::ScanAction).not_to receive(:run)

    mocked_scanner = OpenStruct.new
    allow(::TestCenter::Helper::CorrectingScanHelper).to receive(:new).and_return(mocked_scanner)
    expect(mocked_scanner).to receive(:scan).and_return(true)
    expect(Fastlane::Actions::MultiScanAction).to receive(:run_summary)
    Fastlane::FastFile.new.parse(non_existent_project).runner.execute(:test)
  end

  it 'raises FastlaneTestFailure if tests passed and :fail_build is true' do
    non_existent_project = "lane :test do
      multi_scan(
        project: File.absolute_path('../AtomicBoy/AtomicBoy.xcodeproj'),
        scheme: 'AtomicBoy',
        try_count: 2,
        output_directory: 'path/to',
        test_without_building: true
        # :fail_build is true by default
      )
    end"
    expect(Fastlane::Actions::ScanAction).not_to receive(:run)

    mocked_scanner = OpenStruct.new
    allow(::TestCenter::Helper::CorrectingScanHelper).to receive(:new).and_return(mocked_scanner)
    expect(mocked_scanner).to receive(:scan).and_return(false)
    expect(mocked_scanner).not_to receive(:run_summary)
    expect { Fastlane::FastFile.new.parse(non_existent_project).runner.execute(:test) }.to(
      raise_error(FastlaneCore::Interface::FastlaneTestFailure) do |error|
        expect(error.message).to match('Tests have failed')
      end
    )
  end

  it 'provides a sensible run_summary for 1 retry' do
    allow(Dir).to receive(:glob)
      .with('test_output/**/report*.xml')
      .and_return([File.absolute_path('./spec/fixtures/junit.xml')])

    summary = Fastlane::Actions::MultiScanAction.run_summary(
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
      .and_return([File.absolute_path('./spec/fixtures/junit.xml'), File.absolute_path('./spec/fixtures/junit.xml')])

    allow(Dir).to receive(:glob)
      .with('test_output/**/report*.html')
      .and_return([File.absolute_path('./spec/fixtures/report.html'), File.absolute_path('./spec/fixtures/report.html')])

    allow(Dir).to receive(:glob)
      .with('test_output/**/*.test_result')
      .and_return([File.absolute_path('./spec/fixtures/report.test_result'), File.absolute_path('./spec/fixtures/report.test_result')])

    summary = Fastlane::Actions::MultiScanAction.run_summary(
      {
        output_types: 'html,junit',
        output_files: 'report.html,report.xml',
        output_directory: 'test_output',
        result_bundle: true
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
    expect(summary[:report_files][0]).to match(%r{.*/spec/fixtures/(junit|html).xml})
    expect(summary[:report_files][1]).to match(%r{.*/spec/fixtures/(junit|html).xml})
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
