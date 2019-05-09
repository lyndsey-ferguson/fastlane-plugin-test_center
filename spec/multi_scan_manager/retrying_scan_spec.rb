require 'pry-byebug'
describe TestCenter::Helper::MultiScanManager do
  describe 'retrying_scan', refactor_retrying_scan:true do
    RetryingScan ||= TestCenter::Helper::MultiScanManager::RetryingScan
    RetryingScanHelper ||= TestCenter::Helper::MultiScanManager::RetryingScanHelper

    before(:each) do
      @mock_retrying_scan_helper = OpenStruct.new
      allow(RetryingScanHelper).to receive(:new).and_return(@mock_retrying_scan_helper)
      @mock_retrying_scan_helper_testrun_count = 0
      allow(@mock_retrying_scan_helper).to receive(:after_testrun)
      allow(@mock_retrying_scan_helper).to receive(:testrun_count) do
        @mock_retrying_scan_helper_testrun_count += 1
      end
      allow(Dir).to receive(:glob).and_call_original
      allow(File).to receive(:open).and_call_original
    end

    describe 'scan' do
      it 'is called once if there are no failures' do
        expect(Fastlane::Actions::ScanAction).to receive(:run).once
        retrying_scan = RetryingScan.new
        retrying_scan.run
      end

      it 'succeeds on the third try if there are two failed test runs' do
        expect(Fastlane::Actions::ScanAction).to receive(:run).ordered.once do |config|
          raise FastlaneCore::Interface::FastlaneTestFailure, 'failed tests'
        end
        expect(Fastlane::Actions::ScanAction).to receive(:run).ordered.once do |config|
          raise FastlaneCore::Interface::FastlaneTestFailure, 'failed tests'
        end
        expect(Fastlane::Actions::ScanAction).to receive(:run).ordered.once
        retrying_scan = RetryingScan.new(try_count: 3)
        test_result = retrying_scan.run
        expect(test_result).to be(true)
      end

      it 'fails on the fourth try if there are two failed test runs and :fail_build is false' do
        expect(Fastlane::Actions::ScanAction).to receive(:run).ordered.once do |config|
          raise FastlaneCore::Interface::FastlaneTestFailure, 'failed tests #1'
        end
        expect(Fastlane::Actions::ScanAction).to receive(:run).ordered.once do |config|
          raise FastlaneCore::Interface::FastlaneTestFailure, 'failed tests #2'
        end
        expect(Fastlane::Actions::ScanAction).to receive(:run).ordered.once do |config|
          raise FastlaneCore::Interface::FastlaneTestFailure, 'failed tests #3'
        end
        expect(Fastlane::Actions::ScanAction).to receive(:run).ordered.once do |config|
          raise FastlaneCore::Interface::FastlaneTestFailure, 'failed tests #4'
        end
        retrying_scan = RetryingScan.new(try_count: 4)
        test_result = retrying_scan.run
        expect(test_result).to be(false)
      end

      it 'succeeds on the second tryif the first run generates a build exception that can be recovered from' do
        expect(Fastlane::Actions::ScanAction).to receive(:run).ordered.once do |config|
          raise FastlaneCore::Interface::FastlaneBuildFailure, 'test operation failure'
        end
        expect(Fastlane::Actions::ScanAction).to receive(:run).ordered.once

        retrying_scan = RetryingScan.new(try_count: 3)
        
        test_result = retrying_scan.run
        expect(test_result).to be(true)
      end

      it 'throws an exception if the first run generates a build exception that cannot be recovered from and :fail_build is true' do
        expect(Fastlane::Actions::ScanAction).to receive(:run).ordered.once do |config|
          raise FastlaneCore::Interface::FastlaneBuildFailure, 'something is seriously wrong!'
        end
        expect(Fastlane::Actions::ScanAction).not_to receive(:run).ordered
        allow(@mock_retrying_scan_helper)
          .to receive(:after_testrun)
          .and_raise(FastlaneCore::Interface::FastlaneBuildFailure.new('something is seriously wrong!'))

        retrying_scan = RetryingScan.new

        expect { retrying_scan.run }.to(
          raise_error(FastlaneCore::Interface::FastlaneBuildFailure) do |error|
            expect(error.message).to match("something is seriously wrong!")
          end
        )
      end
    end
  end
end
