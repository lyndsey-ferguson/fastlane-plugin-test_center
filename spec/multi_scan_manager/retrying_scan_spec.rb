describe TestCenter::Helper::MultiScanManager do
  describe 'retrying_scan', refactor_retrying_scan:true do
    RetryingScan ||= TestCenter::Helper::MultiScanManager::RetryingScan
    RetryingScanHelper ||= TestCenter::Helper::MultiScanManager::RetryingScanHelper

    before(:each) do
      @mock_retrying_scan_helper = OpenStruct.new
      allow(@mock_retrying_scan_helper).to receive(:refactor_retrying_scan)
      allow(Dir).to receive(:glob).and_call_original
      allow(File).to receive(:open).and_call_original
    end

    describe 'scan' do
      it 'is called once if there are no failures' do
        expect(Fastlane::Actions::ScanAction).to receive(:run).once
        retrying_scan = RetryingScan.new({}, @mock_retrying_scan_helper)
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
        retrying_scan = RetryingScan.new({}, @mock_retrying_scan_helper)
        retrying_scan.run
      end

      it 'is called twice if the first run generates a build exception that can be recovered from' do
        expect(Fastlane::Actions::ScanAction).to receive(:run).ordered.once do |config|
          raise FastlaneCore::Interface::FastlaneBuildFailure, 'test operation failure'
        end
        expect(Fastlane::Actions::ScanAction).to receive(:run).ordered.once

        retrying_scan = RetryingScan.new({}, @mock_retrying_scan_helper)
        
        retrying_scan.run
      end

      it 'fails if first runner generates a build exception that cannot be recovered from' do
        expect(Fastlane::Actions::ScanAction).to receive(:run).ordered.once do |config|
          raise FastlaneCore::Interface::FastlaneBuildFailure, 'something is seriously wrong!'
        end
        expect(Fastlane::Actions::ScanAction).not_to receive(:run).ordered
        allow(@mock_retrying_scan_helper)
          .to receive(:refactor_retrying_scan)
          .and_raise(FastlaneCore::Interface::FastlaneBuildFailure.new('something is seriously wrong!'))

        retrying_scan = RetryingScan.new({}, @mock_retrying_scan_helper)

        expect { retrying_scan.run }.to(
          raise_error(FastlaneCore::Interface::FastlaneBuildFailure) do |error|
            expect(error.message).to match("something is seriously wrong!")
          end
        )
      end
    end
  end
end
