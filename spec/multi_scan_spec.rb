describe Fastlane::Actions::MultiScanAction do
  before(:each) do
  end

  it 'the project is built if not given :test_without_building' do
    non_existent_project = "lane :test do
      multi_scan(
        project: File.absolute_path('../AtomicBoy/AtomicBoy.xcodeproj'),
        scheme: 'AtomicBoy',
        try_count: 2,
        output_directory: 'path/to'
      )
    end"
    expect(Scan).to receive(:config).and_return({ derived_data_path: '.' })
    expect(Fastlane::Actions::ScanAction).to receive(:run)

    mocked_scanner = OpenStruct.new
    allow(::TestCenter::Helper::CorrectingScanHelper).to receive(:new).and_return(mocked_scanner)
    expect(mocked_scanner).to receive(:scan)
    Fastlane::FastFile.new.parse(non_existent_project).runner.execute(:test)
  end
end
