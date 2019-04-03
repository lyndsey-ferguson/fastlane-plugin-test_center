describe TestCenter::Helper::MultiScanManager do
  describe 'retrying_scan' do
    RetryingScan = TestCenter::Helper::MultiScanManager::RetryingScan

    describe 'scan' do
      skip 'is called once if there are no failures'
      skip 'is called three times if each test run fails twice'
      skip 'is called twice if the first test run experiences testmanagerd connection failures'
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
