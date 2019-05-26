describe Fastlane::Actions::TestsFromXctestrunAction do
  describe 'it handles invalid data' do
    it 'a failure occurs when a non-existent xctestrun file is specified' do
      fastfile = "lane :test do
        tests_from_xctestrun(
          xctestrun: 'path/to/non_existent.xctestrun'
        )
      end"
      expect { Fastlane::FastFile.new.parse(fastfile).runner.execute(:test) }.to(
        raise_error(FastlaneCore::Interface::FastlaneError) do |error|
          expect(error.message).to match("Error: cannot find the xctestrun file 'path/to/non_existent.xctestrun'")
        end
      )
    end
  end

  it 'returns all tests in a xctestrun' do
    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:exist?).with('path/to/fake.xctestrun').and_return(true)
    allow(File).to receive(:read).with('path/to/fake.xctestrun').and_return(File.read('./spec/fixtures/fake.xctestrun'))
    allow(XCTestList)
      .to receive(:tests)
      .with('path/to/Debug-iphonesimulator/AtomicBoy.app/PlugIns/AtomicBoyTests.xctest')
      .and_return(
        [
          'AtomicBoyTests/testUnit1',
          'AtomicBoyTests/testUnit2',
          'AtomicBoyTests/testUnit3'
        ]
      )

    allow(XCTestList)
      .to receive(:tests)
      .with('path/to/Debug-iphonesimulator/AtomicBoyUITests-Runner.app/PlugIns/AtomicBoyUITests.xctest')
      .and_return(
        [
          'AtomicBoyTests/testUI1',
          'AtomicBoyTests/testUI2',
          'AtomicBoyTests/testUI3'
        ]
      )

    fastfile = "lane :test do
      tests_from_xctestrun(
        xctestrun: 'path/to/fake.xctestrun',
      )
    end"
    tests = Fastlane::FastFile.new.parse(fastfile).runner.execute(:test)
    expect(tests).to include(
      'AtomicBoyTests' => [
        'AtomicBoyTests/AtomicBoyTests/testUnit1',
        'AtomicBoyTests/AtomicBoyTests/testUnit2',
        'AtomicBoyTests/AtomicBoyTests/testUnit3'
      ],
      'AtomicBoyUITests' => [
        'AtomicBoyUITests/AtomicBoyTests/testUI1',
        'AtomicBoyUITests/AtomicBoyTests/testUI2',
        'AtomicBoyUITests/AtomicBoyTests/testUI3'
      ]
    )
  end

  it 'displays an error if no tests found in a xctestrun' do
    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:exist?).with('path/to/fake.xctestrun').and_return(true)
    allow(File).to receive(:read).with('path/to/fake.xctestrun').and_return(File.read('./spec/fixtures/fake.xctestrun'))
    allow(XCTestList)
      .to receive(:tests)
      .with('path/to/Debug-iphonesimulator/AtomicBoy.app/PlugIns/AtomicBoyTests.xctest')
      .and_return([])
    allow(XCTestList)
      .to receive(:tests)
      .with('path/to/Debug-iphonesimulator/AtomicBoyUITests-Runner.app/PlugIns/AtomicBoyUITests.xctest')
      .and_return([])
    fastfile = "lane :test do
      tests_from_xctestrun(
        xctestrun: 'path/to/fake.xctestrun'
      )
    end"
    expect(FastlaneCore::UI).to receive(:error).with(/^No tests found.*/).twice
    expect(FastlaneCore::UI).to receive(:important).with(/^Is the Build Setting, `ENABLE_TESTABILITY` enabled.*/).twice
    tests = Fastlane::FastFile.new.parse(fastfile).runner.execute(:test)
    expect(tests).to eq({'AtomicBoyTests' => [], 'AtomicBoyUITests' => [] })
  end
end
