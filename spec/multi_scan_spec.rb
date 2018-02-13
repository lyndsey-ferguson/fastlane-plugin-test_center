describe Fastlane::Actions::MultiScanAction do
  before(:each) do
  end

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
    expect { Fastlane::FastFile.new.parse(non_existent_project).runner.execute(:test) }.to(
      raise_error(FastlaneCore::Interface::FastlaneTestFailure) do |error|
        expect(error.message).to match('Tests have failed')
      end
    )
  end
end
