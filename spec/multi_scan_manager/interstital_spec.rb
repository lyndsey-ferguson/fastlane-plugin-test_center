describe TestCenter::Helper::RetryingScan do
  describe 'interstitial' do

    before(:each) do
      allow(File).to receive(:exist?).and_call_original
    end

    Interstitial = TestCenter::Helper::RetryingScan::Interstitial

    it 'clears out `test_result` bundles when created' do
      allow(Dir).to receive(:glob).and_call_original
      allow(FileUtils).to receive(:rm_rf).and_call_original

      expect(Dir).to receive(:glob).with(/.*\.test_result/).and_return(['./AtomicDragon.test_result'])
      expect(FileUtils).to receive(:rm_rf).with(['./AtomicDragon.test_result'])
      Interstitial.new(
        result_bundle: true,
        output_directory: '.'
      )
    end

    describe '#finish_try' do
      before(:each) do
        @reportnamer = OpenStruct.new
        @stitcher = Interstitial.new(
          output_directory: '.',
          reportnamer: @reportnamer
        )
        allow(@stitcher).to receive(:send_info_for_try)
        allow(@stitcher).to receive(:reset_simulators)
        allow(@stitcher).to receive(:move_test_result_bundle_for_next_run)
        allow(@stitcher).to receive(:set_json_env_if_necessary)
        allow(@reportnamer).to receive(:increment)
      end

      it 'calls :send_info_for_try' do
        expect(@stitcher).to receive(:send_info_for_try).with(3)
        @stitcher.finish_try(3)
      end
      it 'calls :reset_simulators' do
        expect(@stitcher).to receive(:reset_simulators)
        @stitcher.finish_try(3)
      end
      it 'calls :move_test_result_bundle_for_next_run' do
        expect(@stitcher).to receive(:move_test_result_bundle_for_next_run)
        @stitcher.finish_try(3)
      end
      it 'calls :set_json_env_if_necessary' do
        expect(@stitcher).to receive(:set_json_env_if_necessary)
        @stitcher.finish_try(3)
      end
      it 'calls @reportnamer.increment' do
        expect(@reportnamer).to receive(:increment)
        @stitcher.finish_try(3)
      end
    end

    it 'resets a simulator between each run' do
      stitcher = Interstitial.new(
        output_directory: '.'
      )
      mock_devices = [
        FastlaneCore::DeviceManager::Device.new(
          name: 'iPhone Amazing',
          udid: 'E697990C-3A83-4C01-83D1-C367011B31EE',
          os_type: 'iOS',
          os_version: '99.0',
          state: 'Shutdown',
          is_simulator: true
        ),
        FastlaneCore::DeviceManager::Device.new(
          name: 'iPhone Bland',
          udid: 'THIS-IS-A-UNIQUE-DEVICE-ID',
          os_type: 'iOS',
          os_version: '3.0',
          state: 'Booted',
          is_simulator: true
        )
      ]
      allow(Scan).to receive(:config).and_return(
        {
          destination: ['platform=iOS Simulator,id=E697990C-3A83-4C01-83D1-C367011B31EE']
        }
      )
      allow(FastlaneCore::DeviceManager).to receive(:simulators).and_return(mock_devices)
      expect(mock_devices[0]).to receive(:`).with('xcrun simctl erase E697990C-3A83-4C01-83D1-C367011B31EE')
      expect(mock_devices[1]).not_to receive(:reset)
      expect(stitcher).to receive(:send_info_for_try)
      stitcher.finish_try(1)
    end

    describe '#send_info_for_try' do
      it 'sends all info after a run of scan' do
        testrun_completed_block = ->(info) { true }
        expect(testrun_completed_block).to receive(:call).with({
          failed: ['BagOfTests/CoinTossingUITests/testResultIsTails'],
          passing: ['BagOfTests/CoinTossingUITests/testResultIsHeads'],
          batch: 1,
          try_count: 2,
          report_filepath: './relative_path/to/last_produced_junit.xml'
        })
        mock_reportnamer = OpenStruct.new
        allow(mock_reportnamer).to receive(:junit_last_reportname).and_return('relative_path/to/last_produced_junit.xml')

        stitcher = Interstitial.new(
          output_directory: '.',
          batch: 1,
          reportnamer: mock_reportnamer,
          testrun_completed_block: testrun_completed_block
        )
        allow(File).to receive(:exist?).with(%r{.*relative_path/to/last_produced_junit.xml}).and_return(true)
        allow(Fastlane::Actions::TestsFromJunitAction).to receive(:run).and_return(
          {
            failed: ['BagOfTests/CoinTossingUITests/testResultIsTails'],
            passing: ['BagOfTests/CoinTossingUITests/testResultIsHeads']
          }
        )
        stitcher.send_info_for_try(2)
      end

      it 'sends all info and the html report file path after a run of scan' do
        testrun_completed_block = ->(info) { true }
        expect(testrun_completed_block).to receive(:call).with({
          failed: ['BagOfTests/CoinTossingUITests/testResultIsTails'],
          passing: ['BagOfTests/CoinTossingUITests/testResultIsHeads'],
          batch: 1,
          try_count: 2,
          report_filepath: './relative_path/to/last_produced_junit.xml',
          html_report_filepath: './relative_path/to/last_produced_html.html'
        })
        mock_reportnamer = OpenStruct.new
        allow(mock_reportnamer).to receive(:junit_last_reportname).and_return('relative_path/to/last_produced_junit.xml')
        allow(mock_reportnamer).to receive(:includes_html?).and_return(true)
        allow(mock_reportnamer).to receive(:html_last_reportname).and_return('relative_path/to/last_produced_html.html')

        stitcher = Interstitial.new(
          output_directory: '.',
          batch: 1,
          reportnamer: mock_reportnamer,
          testrun_completed_block: testrun_completed_block
        )
        allow(File).to receive(:exist?).with(%r{.*relative_path/to/last_produced_junit.xml}).and_return(true)
        allow(Fastlane::Actions::TestsFromJunitAction).to receive(:run).and_return(
          {
            failed: ['BagOfTests/CoinTossingUITests/testResultIsTails'],
            passing: ['BagOfTests/CoinTossingUITests/testResultIsHeads']
          }
        )
        stitcher.send_info_for_try(2)
      end

      it 'sends all info and the json report file path after a run of scan' do
        testrun_completed_block = ->(info) { true }
        expect(testrun_completed_block).to receive(:call).with({
          failed: ['BagOfTests/CoinTossingUITests/testResultIsTails'],
          passing: ['BagOfTests/CoinTossingUITests/testResultIsHeads'],
          batch: 1,
          try_count: 2,
          report_filepath: './relative_path/to/last_produced_junit.xml',
          json_report_filepath: './relative_path/to/last_produced.json'
        })
        mock_reportnamer = OpenStruct.new
        allow(mock_reportnamer).to receive(:junit_last_reportname).and_return('relative_path/to/last_produced_junit.xml')
        allow(mock_reportnamer).to receive(:includes_json?).and_return(true)
        allow(mock_reportnamer).to receive(:json_last_reportname).and_return('relative_path/to/last_produced.json')
        stitcher = Interstitial.new(
          output_directory: '.',
          reportnamer: mock_reportnamer,
          batch: 1,
          testrun_completed_block: testrun_completed_block
        )
        allow(File).to receive(:exist?).with(%r{.*relative_path/to/last_produced_junit.xml}).and_return(true)
        allow(Fastlane::Actions::TestsFromJunitAction).to receive(:run).and_return(
          {
            failed: ['BagOfTests/CoinTossingUITests/testResultIsTails'],
            passing: ['BagOfTests/CoinTossingUITests/testResultIsHeads']
          }
        )
        stitcher.send_info_for_try(2)
      end

      it 'sends all info and the test result bundlepath after a run of scan' do
        testrun_completed_block = ->(info) { true }
        expect(testrun_completed_block).to receive(:call).with({
          failed: ['BagOfTests/CoinTossingUITests/testResultIsTails'],
          passing: ['BagOfTests/CoinTossingUITests/testResultIsHeads'],
          batch: 1,
          try_count: 2,
          report_filepath: './relative_path/to/last_produced_junit.xml',
          test_result_bundlepath: './AtomicHeart.test_result'
        })
        mock_reportnamer = OpenStruct.new
        allow(mock_reportnamer).to receive(:report_count).and_return(0)
        allow(mock_reportnamer).to receive(:junit_last_reportname).and_return('relative_path/to/last_produced_junit.xml')
        stitcher = Interstitial.new(
          output_directory: '.',
          result_bundle: true,
          scheme: 'AtomicHeart',
          reportnamer: mock_reportnamer,
          batch: 1,
          testrun_completed_block: testrun_completed_block
        )
        allow(File).to receive(:exist?).with(%r{.*relative_path/to/last_produced_junit.xml}).and_return(true)
        allow(Fastlane::Actions::TestsFromJunitAction).to receive(:run).and_return(
          {
            failed: ['BagOfTests/CoinTossingUITests/testResultIsTails'],
            passing: ['BagOfTests/CoinTossingUITests/testResultIsHeads']
          }
        )
        stitcher.send_info_for_try(2)

        expect(testrun_completed_block).to receive(:call).with({
          failed: ['BagOfTests/CoinTossingUITests/testResultIsTails'],
          passing: ['BagOfTests/CoinTossingUITests/testResultIsHeads'],
          batch: 1,
          try_count: 2,
          report_filepath: './relative_path/to/last_produced_junit.xml',
          test_result_bundlepath: './AtomicHeart-1.test_result'
        })
        allow(mock_reportnamer).to receive(:report_count).and_return(1)
        stitcher.send_info_for_try(2)
      end
    end

    describe 'JSON reports' do
      before(:each) do
        @mock_reportnamer = OpenStruct.new
        allow(@mock_reportnamer).to receive(:junit_last_reportname).and_return('relative_path/to/last_produced_junit.xml')
        allow(@mock_reportnamer).to receive(:includes_json?).and_return(true)
        allow(@mock_reportnamer).to receive(:json_last_reportname).and_return('relative_path/to/last_produced_json.json')
        @json_file_output = 'sillywalk_path/to/monkey_business'
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('XCPRETTY_JSON_FILE_OUTPUT').and_return(@json_file_output)
        allow(ENV).to receive(:[]=).and_call_original
        allow(ENV).to receive(:[]=).with('XCPRETTY_JSON_FILE_OUTPUT', anything) do |k, v|
          @json_file_output = v
        end
      end

      it 'changes the XCPRETTY_JSON_FILE_OUTPUT env var appropriately' do
        Interstitial.new(
          result_bundle: true,
          output_directory: '.',
          reportnamer: @mock_reportnamer
        )
        expect(@json_file_output).to eq('./relative_path/to/last_produced_json.json')
      end

      it 'resets the XCPRETTY_JSON_FILE_OUTPUT when :after_all is called' do
        interstitial = Interstitial.new(
          result_bundle: true,
          output_directory: '.',
          reportnamer: @mock_reportnamer
        )
        interstitial.after_all
        expect(@json_file_output).to eq('sillywalk_path/to/monkey_business')
      end
    end
  end
end
