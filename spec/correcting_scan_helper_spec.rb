require 'json'
CorrectingScanHelper = TestCenter::Helper::CorrectingScanHelper
describe TestCenter do
  describe TestCenter::Helper do
    describe CorrectingScanHelper do
      describe 'scan' do
        before(:each) do
          @mock_reportnamer = OpenStruct.new
          allow(TestCenter::Helper::ReportNameHelper).to receive(:new).and_return(@mock_reportnamer)

          @mock_interstitcher = OpenStruct.new
          allow(TestCenter::Helper::RetryingScan::Interstitial).to receive(:new).and_return(@mock_interstitcher)

          @mock_testcollector = OpenStruct.new
          allow(TestCenter::Helper::TestCollector).to receive(:new).and_return(@mock_testcollector)

          @mock_collator = OpenStruct.new
          allow(TestCenter::Helper::RetryingScan::ReportCollator).to receive(:new).and_return(@mock_collator)

          allow(File).to receive(:exist?).and_call_original
        end

        it 'calls intersitial\'s before_all before :correcting_scan' do
          allow(@mock_testcollector).to receive(:testables).and_return([nil, nil])
          allow(@mock_testcollector).to receive(:test_batches).and_return(
            [
              ['AtomicBoyTests/testOne'],
              ['AtomicBoyUITests/testOne']
            ]
          )
          scanner = CorrectingScanHelper.new(
            xctestrun: 'path/to/fake.xctestrun',
            result_bundle: true,
            output_directory: '.',
            scheme: 'AtomicBoy'
          )
          allow(scanner).to receive(:correcting_scan)
          allow(scanner).to receive(:setup_simulators)
          allow(TestCenter::Helper::RetryingScan::Interstitial).to receive(:new).and_return(@mock_interstitcher)
          expect(@mock_interstitcher).to receive(:before_all).twice
          scanner.scan
        end
      end

      describe 'correcting_scan' do
        before(:each) do
          allow(Fastlane::Actions).to receive(:sh)
          allow_any_instance_of(CorrectingScanHelper).to receive(:sleep)

          @mock_interstitcher = OpenStruct.new
          allow(@mock_interstitcher).to receive(:finish_try)
          allow(TestCenter::Helper::RetryingScan::Interstitial).to receive(:new).and_return(@mock_interstitcher)

          @mock_testcollector = OpenStruct.new
          allow(TestCenter::Helper::TestCollector).to receive(:new).and_return(@mock_testcollector)
        end
        describe 'one testable' do
          describe 'code coverage' do
            before(:each) do
              allow(File).to receive(:exist?).and_call_original
              allow(File).to receive(:exist?).and_return(true)
              allow(@mock_testcollector).to receive(:testables).and_return(['AtomicBoyTests'])
              allow(@mock_testcollector).to receive(:test_batches).and_return({'AtomicBoyTests' => ['AtomicBoyTests']})
            end

            it 'stops sending :code_coverage down after the first run' do
              scanner = CorrectingScanHelper.new(
                xctestrun: 'path/to/fake.xctestrun',
                output_directory: '.',
                try_count: 2,
                batch_count: 2,
                clean: true,
                code_coverage: true
              )
              scanner.reset_for_new_testable('.')
              allow(scanner).to receive(:failed_tests).and_return(['AtomicBoyUITests/AtomicBoyUITests/testExample3'])
              allow(scanner).to receive(:testrun_info).and_return({ failed: [] })
              expect(Fastlane::Actions::ScanAction).to receive(:run).ordered.once do |config|
                expect(config._values).to have_key(:code_coverage)
                expect(config._values[:code_coverage]).to eq(true)
                raise FastlaneCore::Interface::FastlaneTestFailure, 'failed tests'
              end
              expect(Fastlane::Actions::ScanAction).to receive(:run).ordered.once do |config|
                expect(config._values).not_to have_key(:code_coverage)
              end
              scanner.correcting_scan(
                {
                  output_directory: '.'
                },
                1,
                ReportNameHelper.new('html,junit')
              )
            end
          end

          describe 'no batches' do
            before(:all) do
              @xcpretty_json_file_output = ENV['XCPRETTY_JSON_FILE_OUTPUT']
            end
            after(:all) do
              ENV['XCPRETTY_JSON_FILE_OUTPUT'] = @xcpretty_json_file_output
            end

            before(:each) do
              allow(File).to receive(:exist?).and_call_original
              allow(File).to receive(:exist?).and_return(true)
              allow(@mock_testcollector).to receive(:testables).and_return(['AtomicBoyTests'])
              allow(@mock_testcollector).to receive(:test_batches).and_return(['AtomicBoyTests' => ['AtomicBoyTests']])
            end

            it 'calls scan once with no failures' do
              scanner = CorrectingScanHelper.new(
                xctestrun: 'path/to/fake.xctestrun',
                output_directory: '.',
                try_count: 2,
                batch_count: 2,
                clean: true
              )
              scanner.reset_for_new_testable('.')
              expect(Fastlane::Actions::ScanAction).to receive(:run).once do |config|
                expect(config._values).to have_key(:output_files)
                expect(config._values).not_to have_key(:try_count)
                expect(config._values).not_to have_key(:batch_count)
                expect(config._values[:clean]).to be(false)
                expect(config._values).not_to have_key(:custom_report_file_name)
                expect(config._values[:output_files]).to eq('report.html,report.junit')
              end
              result = scanner.correcting_scan(
                {
                  output_directory: '.'
                },
                1,
                ReportNameHelper.new('html,junit')
              )
              expect(scanner.retry_total_count).to eq(0)
              expect(result).to eq(true)
            end

            it 'calls scan three times when two runs have failures' do
              scanner = CorrectingScanHelper.new(
                xctestrun: 'path/to/fake.xctestrun',
                output_directory: '.',
                try_count: 3,
                quit_simulators: true
              )
              allow(File).to receive(:exist?).and_call_original
              allow(File).to receive(:exist?).with(%r{.*/report(-[23])?.junit}).and_return(true)
              expected_report_files = ['.*/report.junit', '.*/report-2.junit', '.*/report-3.junit']
              allow(Fastlane::Actions::TestsFromJunitAction).to receive(:run) do |config|
                expect(config._values).to have_key(:junit)
                expect(config._values[:junit]).to match(expected_report_files.shift)
                { failed: ['BagOfTests/CoinTossingUITests/testResultIsTails'] }
              end
              expect(Fastlane::Actions::ScanAction).to receive(:run).ordered.once do |config|
                expect(config._values).to have_key(:output_files)
                expect(config._values[:output_files]).to eq('report.html,report.junit')
                raise FastlaneCore::Interface::FastlaneTestFailure, 'failed tests'
              end
              expect(Fastlane::Actions::ScanAction).to receive(:run).ordered.once do |config|
                expect(config._values).to have_key(:output_files)
                expect(config._values[:output_files]).to eq('report-2.html,report-2.junit')
                raise FastlaneCore::Interface::FastlaneTestFailure, 'failed tests'
              end
              expect(Fastlane::Actions::ScanAction).to receive(:run).ordered.once do |config|
                expect(config._values).to have_key(:output_files)
                expect(config._values[:output_files]).to eq('report-3.html,report-3.junit')
                expect(config._values).to have_key(:only_testing)
                expect(config._values[:only_testing]).to eq(['BagOfTests/CoinTossingUITests/testResultIsTails'])
                raise FastlaneCore::Interface::FastlaneTestFailure, 'failed tests'
              end

              expect(Fastlane::Actions).to receive(:sh).with(/killall -9 'iPhone Simulator' 'Simulator' 'SimulatorBridge'.*/, anything).at_least(3).times
              result = scanner.correcting_scan(
                {
                  output_directory: '.'
                },
                1,
                ReportNameHelper.new('html,junit')
              )
              expect(scanner.retry_total_count).to eq(2)
              expect(result).to eq(false)
            end

            it 'calls scan three times when two runs have failures without killing the simulator' do
              scanner = CorrectingScanHelper.new(
                xctestrun: 'path/to/fake.xctestrun',
                output_directory: '.',
                try_count: 3,
                quit_simulators: false
              )
              scanner.reset_for_new_testable('.')
              allow(File).to receive(:exist?).and_call_original
              allow(File).to receive(:exist?).with(%r{.*/report(-[23])?.junit}).and_return(true)
              allow(scanner).to receive(:failed_tests).and_return(['BagOfTests/CoinTossingUITests/testResultIsTails'])
              expect(Fastlane::Actions::ScanAction).to receive(:run).ordered.once do |config|
                raise FastlaneCore::Interface::FastlaneTestFailure, 'failed tests'
              end
              expect(Fastlane::Actions::ScanAction).to receive(:run).ordered.once do |config|
                raise FastlaneCore::Interface::FastlaneTestFailure, 'failed tests'
              end
              expect(Fastlane::Actions::ScanAction).to receive(:run).ordered.once do |config|
                raise FastlaneCore::Interface::FastlaneTestFailure, 'failed tests'
              end

              expect(Fastlane::Actions).not_to receive(:sh).with(/killall -9 'iPhone Simulator' 'Simulator' 'SimulatorBridge'.*/, anything)
              result = scanner.correcting_scan(
                {
                  output_directory: '.'
                },
                1,
                ReportNameHelper.new('html,junit')
              )
              expect(scanner.retry_total_count).to eq(2)
              expect(result).to eq(false)
            end
          end
        end
      end
    end
  end
end
