module TestCenter::Helper
  describe 'XCTestrunInfo' do
    it 'raises and error when given an xctestrun file that does not exist' do
      expect { XCTestrunInfo.new('path/to/non-existent.xctestrun') }.to (
        raise_error(Errno::ENOENT) do |error|
          expect(error.message).to eq('No such file or directory - path/to/non-existent.xctestrun')
        end
      )
    end

    it 'provides the file path to the app to be tested a UI test target' do
      info = XCTestrunInfo.new('./spec/fixtures/fake.xctestrun')
      expect(info.app_path_for_testable('AtomicBoyUITests')).to eq("./spec/fixtures/Debug-iphonesimulator/AtomicBoy.app")
    end

    it 'provides the file path to the app to be tested a non-UI test target' do
      info = XCTestrunInfo.new('./spec/fixtures/fake.xctestrun')
      expect(info.app_path_for_testable('Atomic Boy Tests')).to eq("./spec/fixtures/Debug-iphonesimulator/AtomicBoy.app")
    end

    it 'provides the info plist for the app' do
      infoplist = XCTestrunInfo.new('./spec/fixtures/fake.xctestrun').app_plist_for_testable('Atomic Boy Tests')
      expect(infoplist['MinimumOSVersion']).to eq('11.0')
    end
  end
end
