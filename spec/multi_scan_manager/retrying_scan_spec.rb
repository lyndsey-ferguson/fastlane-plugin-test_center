describe TestCenter::Helper::MultiScanManager do
  describe 'retrying_scan', retrying_scan:true do
    RetryingScan ||= TestCenter::Helper::MultiScanManager::RetryingScan

    before(:each) do
      allow(Dir).to receive(:glob).and_call_original
      allow(File).to receive(:open).and_call_original
    end

    describe 'scan' do
      it 'is called once if there are no failures' do
        expect(Fastlane::Actions::ScanAction).to receive(:run).once
        retrying_scan = RetryingScan.new
        retrying_scan.run
      end

      it 'is called three times if each test run fails twice' do
        expect(Fastlane::Actions::ScanAction).to receive(:run).ordered.once do |config|
          raise FastlaneCore::Interface::FastlaneTestFailure, 'failed tests'
        end
        expect(Fastlane::Actions::ScanAction).to receive(:run).ordered.once do |config|
          raise FastlaneCore::Interface::FastlaneTestFailure, 'failed tests'
        end
        expect(Fastlane::Actions::ScanAction).to receive(:run).ordered.once do |config|
          raise FastlaneCore::Interface::FastlaneTestFailure, 'failed tests'
        end
        retrying_scan = RetryingScan.new
        retrying_scan.run
      end

      it 'is called twice if the first run fails to connect to the test runner' do
        expect(Fastlane::Actions::ScanAction).to receive(:run).ordered.once do |config|
          raise FastlaneCore::Interface::FastlaneBuildFailure, 'test operation failure'
        end
        expect(Fastlane::Actions::ScanAction).to receive(:run).ordered.once

        scan_options = { derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr' }

        retrying_scan = RetryingScan.new(
          scan_options: scan_options
        )
        session_log_io = StringIO.new('Test operation failure: Test runner exited before starting test execution')
        allow(session_log_io).to receive(:stat).and_return(OpenStruct.new(size: session_log_io.size))

        allow(Dir).to receive(:glob)
                  .with(%r{.*AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr/Logs/Test/\*\.xcresult/\*_Test/Diagnostics/\*\*/Session-\*\.log})
                  .and_return(['A/B/C/Session-AtomicBoyUITests-Today.log', 'D/E/F/Session-AtomicBoyUITests-Today.log'])

        allow(File).to receive(:mtime).with('A/B/C/Session-AtomicBoyUITests-Today.log').and_return(1)
        allow(File).to receive(:mtime).with('D/E/F/Session-AtomicBoyUITests-Today.log').and_return(2)
        allow(File).to receive(:open).with('D/E/F/Session-AtomicBoyUITests-Today.log').and_return(session_log_io)
        
        retrying_scan.run
      end

      it 'fails if the test runner fails to connect to testmanagerd' do
        expect(Fastlane::Actions::ScanAction).to receive(:run).ordered.once do |config|
          raise FastlaneCore::Interface::FastlaneBuildFailure, 'failed to connect to testmanagerd'
        end
        expect(FastlaneCore::UI).to receive(:error).with(/Test Manager Daemon/)
        expect(Fastlane::Actions::ScanAction).not_to receive(:run).ordered
        scan_options = { derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr' }

        retrying_scan = RetryingScan.new(
          scan_options: scan_options
        )
        session_log_io = StringIO.new('Test operation failure: Lost connection to testmanagerd')
        allow(session_log_io).to receive(:stat).and_return(OpenStruct.new(size: session_log_io.size))

        allow(Dir).to receive(:glob)
                  .with(%r{.*AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr/Logs/Test/\*\.xcresult/\*_Test/Diagnostics/\*\*/Session-\*\.log})
                  .and_return(['A/B/C/Session-AtomicBoyUITests-Today.log', 'D/E/F/Session-AtomicBoyUITests-Today.log'])

        allow(File).to receive(:mtime).with('A/B/C/Session-AtomicBoyUITests-Today.log').and_return(1)
        allow(File).to receive(:mtime).with('D/E/F/Session-AtomicBoyUITests-Today.log').and_return(2)
        allow(File).to receive(:open).with('D/E/F/Session-AtomicBoyUITests-Today.log').and_return(session_log_io)
        

        retrying_scan.run
      end

      it 'restarts the com.apple.CoreSimulator.CoreSimulatorService on testmanagerd connection failures if desired and retries to test' do
        expect(Fastlane::Actions::ScanAction).to receive(:run).ordered.once do |config|
          raise FastlaneCore::Interface::FastlaneBuildFailure, 'failed to connect to testmanagerd'
        end
        expect(FastlaneCore::UI).to receive(:error).with(/Test Manager Daemon/)
        expect(Fastlane::Actions::RestartCoreSimulatorServiceAction).to receive(:run).ordered.once
        expect(Fastlane::Actions::ScanAction).to receive(:run).ordered.once
        scan_options = { 
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          quit_core_simulator_service: true
        }

        retrying_scan = RetryingScan.new(
          scan_options: scan_options
        )
        session_log_io = StringIO.new('Test operation failure: Lost connection to testmanagerd')
        allow(session_log_io).to receive(:stat).and_return(OpenStruct.new(size: session_log_io.size))

        allow(Dir).to receive(:glob)
                  .with(%r{.*AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr/Logs/Test/\*\.xcresult/\*_Test/Diagnostics/\*\*/Session-\*\.log})
                  .and_return(['A/B/C/Session-AtomicBoyUITests-Today.log', 'D/E/F/Session-AtomicBoyUITests-Today.log'])

        allow(File).to receive(:mtime).with('A/B/C/Session-AtomicBoyUITests-Today.log').and_return(1)
        allow(File).to receive(:mtime).with('D/E/F/Session-AtomicBoyUITests-Today.log').and_return(2)
        allow(File).to receive(:open).with('D/E/F/Session-AtomicBoyUITests-Today.log').and_return(session_log_io)
        

        retrying_scan.run
      end

      # /Users/lyndsey.ferguson/Library/Developer/Xcode/DerivedData/AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr/Logs/Test/Test-Transient Testing-2019.04.08_16-32-28--0400.xcresult/1_Test/Diagnostics/AtomicBoyUITests-C73745AD-9DA7-4539-81DD-DE7C45152B71/AtomicBoyUITests-69F8BF52-FFEE-40A9-B50F-152041E06DF9/Session-AtomicBoyUITests-2019-04-08_163229-83OA4g.log
      # /Users/lyndsey.ferguson/Library/Developer/Xcode/DerivedData/AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr <= derived data path
      # look for most recently modified Session-testtarget.log
      # look for 'Test operation failure: Test runner exited before starting test execution'
      # look for 'Test operation failure: Lost connection to testmanagerd'

      skip 'is called only once if the first test run crashes'
    end

    describe 'scan_helper' do
      describe 'before the first scan' do
        skip 'quits com.apple.CoreSimulator.CoreSimulatorService'
        skip 'creates the clones of simulators'
      end

      describe 'before a scan' do
        skip 'clears out pre-existing test bundles before scan'
        skip 'sets up JSON xcpretty output option'
        skip 'resets the simulators'

        describe 'the options' do
          skip 'updates the reportnamer'
        end

      end

      describe 'after a scan' do
        skip 'updates the test bundle name after a scan'
        skip 'resets the JSON xcpretty output option'
        skip 'sends info about the last test run to the test_run callback'
      end

    end
  end
end
