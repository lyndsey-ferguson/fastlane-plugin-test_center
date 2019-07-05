module TestCenter::Helper::MultiScanManager
  describe 'retrying_scan_helper' do

    before(:each) do
      allow(Dir).to receive(:glob).and_call_original
      allow(File).to receive(:open).and_call_original
      allow(Scan).to receive(:config).and_return(derived_data_path: '')
      allow(Scan).to receive(:config=)
      allow(FastlaneCore::UI).to receive(:message).and_call_original
      allow(FileUtils).to receive(:rm_rf).and_call_original
      @xcpretty_json_file_output = ENV['XCPRETTY_JSON_FILE_OUTPUT']
      mocked_report_collator = OpenStruct.new
      allow(mocked_report_collator).to receive(:collate)
      allow(TestCenter::Helper::MultiScanManager::ReportCollator).to receive(:new).and_return(mocked_report_collator)
    end

    after(:each) do
      ENV['XCPRETTY_JSON_FILE_OUTPUT'] = @xcpretty_json_file_output
    end

    describe 'before_testrun' do
      it 'clears out pre-existing xcresult directory' do
        allow(Dir).to receive(:glob).with(%r{/.*/path/to/AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr/.*\.xcresult}).and_return(['./AtomicDragon.xcresult'])
        helper = RetryingScanHelper.new(
          derived_data_path: 'path/to/AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          output_directory: File.absolute_path('./path/to/output/directory')
        )
        expect(FileUtils).to receive(:rm_rf).with(['./AtomicDragon.xcresult'])
        helper.before_testrun
      end

      it 'prints to the console a message that a test_run is being started' do
        helper = RetryingScanHelper.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          output_directory: File.absolute_path('./path/to/output/directory'),
          only_testing: [
            'BagOfTests/CoinTossingUITests/testResultIsTails',
            'BagOfTests/CoinTossingUITests/testResultIsHeads',
            'BagOfTests/CoinTossingUITests/testResultIsOnEdge'
          ]
        )
        expect(FastlaneCore::UI).to receive(:message).with(/Starting scan #1 with 3 tests/)
        helper.before_testrun
      end

      it 'prints to the console a message that a test_run for a batch is being started' do
        helper = RetryingScanHelper.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          output_directory: File.absolute_path('./path/to/output/directory'),
          only_testing: [
            'BagOfTests/CoinTossingUITests/testResultIsTails',
            'BagOfTests/CoinTossingUITests/testResultIsHeads',
            'BagOfTests/CoinTossingUITests/testResultIsOnEdge'
          ],
          batch: 2,
          output_files: 'coinTossResult.html,coinTossResult.junit',
          output_types: 'html,junit'
        )
        expect(FastlaneCore::UI).to receive(:message).with(/Starting scan #1 with 3 tests for batch #2/)
        helper.before_testrun
      end
    end

    describe 'after_testrun' do
      it 'raises if there is a random build failure' do
        helper = RetryingScanHelper.new({derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr'})

        session_log_io = StringIO.new('Everything went wrong!')
        allow(session_log_io).to receive(:stat).and_return(OpenStruct.new(size: session_log_io.size))
  
        allow(Dir).to receive(:glob)
                  .with(%r{.*AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr/Logs/Test/\*\.xcresult/\*_Test/Diagnostics/\*\*/Session-\*\.log})
                  .and_return(['A/B/C/Session-AtomicBoyUITests-Today.log', 'D/E/F/Session-AtomicBoyUITests-Today.log'])
  
        allow(File).to receive(:mtime).with('A/B/C/Session-AtomicBoyUITests-Today.log').and_return(1)
        allow(File).to receive(:mtime).with('D/E/F/Session-AtomicBoyUITests-Today.log').and_return(2)
        allow(File).to receive(:open).with('D/E/F/Session-AtomicBoyUITests-Today.log').and_return(session_log_io)

        expect {
          helper.after_testrun(
            FastlaneCore::Interface::FastlaneBuildFailure.new('chaos')
          )
        }.to(
          raise_error(FastlaneCore::Interface::FastlaneBuildFailure) do |error|
            expect(error.message).to match("chaos")
          end
        )
      end

      it 'does not raise if there is a test runner early exit failure' do
        helper = RetryingScanHelper.new({derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr', output_directory: ''})
        
        session_log_io = StringIO.new('Test operation failure: Test runner exited before starting test execution')
        allow(session_log_io).to receive(:stat).and_return(OpenStruct.new(size: session_log_io.size))
  
        allow(Dir).to receive(:glob)
                  .with(%r{.*AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr/Logs/Test/\*\.xcresult/\*_Test/Diagnostics/\*\*/Session-\*\.log})
                  .and_return(['A/B/C/Session-AtomicBoyUITests-Today.log', 'D/E/F/Session-AtomicBoyUITests-Today.log'])
  
        allow(File).to receive(:mtime).with('A/B/C/Session-AtomicBoyUITests-Today.log').and_return(1)
        allow(File).to receive(:mtime).with('D/E/F/Session-AtomicBoyUITests-Today.log').and_return(2)
        allow(File).to receive(:open).with('D/E/F/Session-AtomicBoyUITests-Today.log').and_return(session_log_io)
        
        helper.after_testrun(FastlaneCore::Interface::FastlaneBuildFailure.new('test failure'))
      end

      it 'resets the simulators' do
        cloned_simulators = [
          OpenStruct.new(name: 'Clone 1'),
          OpenStruct.new(name: 'Clone 2')
        ]
        helper = RetryingScanHelper.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          simulators: cloned_simulators,
          reset_simulators: true,
          output_directory: ''
        )
        
        session_log_io = StringIO.new('Test operation failure: Test runner exited before starting test execution')
        allow(session_log_io).to receive(:stat).and_return(OpenStruct.new(size: session_log_io.size))
  
        allow(Dir).to receive(:glob)
                  .with(%r{.*AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr/Logs/Test/\*\.xcresult/\*_Test/Diagnostics/\*\*/Session-\*\.log})
                  .and_return(['A/B/C/Session-AtomicBoyUITests-Today.log', 'D/E/F/Session-AtomicBoyUITests-Today.log'])
  
        allow(File).to receive(:mtime).with('A/B/C/Session-AtomicBoyUITests-Today.log').and_return(1)
        allow(File).to receive(:mtime).with('D/E/F/Session-AtomicBoyUITests-Today.log').and_return(2)
        allow(File).to receive(:open).with('D/E/F/Session-AtomicBoyUITests-Today.log').and_return(session_log_io)
        
        cloned_simulators.each do |cloned_simulator|
          expect(cloned_simulator).to receive(:reset)
        end
        helper.after_testrun(FastlaneCore::Interface::FastlaneBuildFailure.new('test failure'))
      end

      it 'renames the resultant test bundle after failure' do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(%r{.*/path/to/output/directory/report(-\d)?\.junit}).and_return(true)
        allow(Fastlane::Actions::TestsFromJunitAction).to receive(:run).and_return(
          failed: ['BagOfTests/CoinTossingUITests/testResultIsTails']
        )
        
        allow(Dir).to receive(:glob).with(%r{/.*/path/to/output/directory/.*\.test_result}).and_return(['./AtomicDragon.test_result', './AtomicDragon-99.test_result'])
        allow(FileUtils).to receive(:mkdir_p)
        helper = RetryingScanHelper.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          output_directory: File.absolute_path('./path/to/output/directory'),
          result_bundle: true
        )
        expect(File).to receive(:rename).with('./AtomicDragon.test_result', './AtomicDragon-1.test_result')
        helper.after_testrun(FastlaneCore::Interface::FastlaneTestFailure.new('test failure'))
        expect(File).to receive(:rename).with('./AtomicDragon.test_result', './AtomicDragon-2.test_result')
        helper.after_testrun(FastlaneCore::Interface::FastlaneTestFailure.new('test failure'))
        expect(File).to receive(:rename).with('./AtomicDragon.test_result', './AtomicDragon-3.test_result')
        helper.after_testrun(FastlaneCore::Interface::FastlaneTestFailure.new('test failure'))
      end

      it 'resets the JSON xcpretty output option' do
        ENV['XCPRETTY_JSON_FILE_OUTPUT'] = './original/path/to/output/directory/xcpretty.json'
        allow(ENV).to receive(:[]=).and_call_original
        helper = RetryingScanHelper.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          output_directory: File.absolute_path('./path/to/output/directory'),
          output_types: 'json',
          output_files: 'report.json'
        )
        expect(ENV).to receive(:[]=).with('XCPRETTY_JSON_FILE_OUTPUT', './original/path/to/output/directory/xcpretty.json')
        helper.after_testrun
      end

      it 'collates the reports after a success' do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(%r{.*/path/to/output/directory/report(-\d)?\.junit}).and_return(true)
        allow(Fastlane::Actions::TestsFromJunitAction).to receive(:run).and_return(
          failed: ['BagOfTests/CoinTossingUITests/testResultIsTails']
        )
        mocked_report_collator = OpenStruct.new
        expect(TestCenter::Helper::MultiScanManager::ReportCollator).to receive(:new)
          .with(
            source_reports_directory_glob: File.absolute_path('./path/to/output/directory'),
            output_directory: File.absolute_path('./path/to/output/directory'),
            reportnamer: anything,
            scheme: 'AtomicUITests',
            result_bundle: nil
          )
          .and_return(mocked_report_collator)
        expect(mocked_report_collator).to receive(:collate)

        helper = RetryingScanHelper.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          scheme: 'AtomicUITests',
          output_directory: File.absolute_path('./path/to/output/directory'),
          collate_reports: true
        )
        helper.after_testrun(FastlaneCore::Interface::FastlaneTestFailure.new('test failure'))
        helper.after_testrun(FastlaneCore::Interface::FastlaneTestFailure.new('test failure'))
        helper.after_testrun
      end

      it 'collates the reports after successive failures' do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(%r{.*/path/to/output/directory/report(-\d)?\.junit}).and_return(true)
        allow(Fastlane::Actions::TestsFromJunitAction).to receive(:run).and_return(
          failed: ['BagOfTests/CoinTossingUITests/testResultIsTails']
        )
        mocked_report_collator = OpenStruct.new
        expect(TestCenter::Helper::MultiScanManager::ReportCollator).to receive(:new)
          .with(
            source_reports_directory_glob: File.absolute_path('./path/to/output/directory'),
            output_directory: File.absolute_path('./path/to/output/directory'),
            reportnamer: anything,
            scheme: 'AtomicUITests',
            result_bundle: nil
          )
          .and_return(mocked_report_collator)
        expect(mocked_report_collator).to receive(:collate)

        helper = RetryingScanHelper.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          scheme: 'AtomicUITests',
          output_directory: File.absolute_path('./path/to/output/directory'),
          collate_reports: true
        )
        helper.after_testrun(FastlaneCore::Interface::FastlaneTestFailure.new('test failure'))
      end

      it 'will collate the reports into a file that has the batch information' do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(%r{.*/path/to/output/directory/BagOfTests-batch-2/report(-\d)?\.(junit|html)}).and_return(true)
        allow(Fastlane::Actions::TestsFromJunitAction).to receive(:run).and_return(
          failed: ['BagOfTests/CoinTossingUITests/testResultIsTails']
        )
        
        expect(TestCenter::Helper::MultiScanManager::ReportCollator).to receive(:new).with(
          source_reports_directory_glob: File.absolute_path('./path/to/output/directory/BagOfTests-batch-2'),
          output_directory: File.absolute_path('./path/to/output/directory/BagOfTests-batch-2'),
          reportnamer: anything,
          scheme: 'AtomicUITests',
          result_bundle: anything
        )
        helper = RetryingScanHelper.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          scheme: 'AtomicUITests',
          output_directory: File.absolute_path('./path/to/output/directory/BagOfTests-batch-2'),
          only_testing: ['BagOfTests/CoinTossingUITests/testResultIsTails'],
          batch: 2,
          batch_count: 3,
          output_types: 'junit,html',
          output_files: 'report.junit,report.html',
          collate_reports: true
        )
        helper.after_testrun(FastlaneCore::Interface::FastlaneTestFailure.new('test failure'))
      end
    end

    describe '#quit_simulator' do
      it 'quits the simulator if requested' do
        helper = RetryingScanHelper.new(
          destination: ["platform=iOS Simulator,id=A00", "platform=iOS Simulator,id=BAF"],
          quit_simulators: true
        )
        expect(helper).to receive(:`).with('xcrun simctl shutdown A00 2>/dev/null')
        expect(helper).to receive(:`).with('xcrun simctl shutdown BAF 2>/dev/null')
        helper.quit_simulator
      end

      it 'does not quits the simulator when not requested' do
        helper = RetryingScanHelper.new(destination: "platform=iOS Simulator,id=A00")
        expect(helper).not_to receive(:`)
        helper.quit_simulator
      end
    end

    describe 'scan_options' do
      it 'has the tests to be tested' do
        helper = RetryingScanHelper.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          only_testing: ['BagOfTests/CoinTossingUITests/testResultIsTails'],
          output_directory: File.absolute_path('./path/to/output/directory')
        )

        expect(helper.scan_options).to include(
          only_testing: ['BagOfTests/CoinTossingUITests/testResultIsTails']
        )
      end

      it 'does not have any non-scan options' do
        helper = RetryingScanHelper.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          only_testing: ['BagOfTests/CoinTossingUITests/testResultIsTails'],
          batch_count: 4,
          parallelize: true,
          output_directory: File.absolute_path('./path/to/output/directory')
        )
        expect(helper.scan_options.keys).not_to include(:batch_count, :parallelize)
        expect(helper.scan_options.keys).to include(:derived_data_path, :only_testing)
      end
      
      it 'has only the failing tests' do
        helper = RetryingScanHelper.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          output_directory: File.absolute_path('./path/to/output/directory'),
          only_testing: [
            'BagOfTests/CoinTossingUITests/testResultIsTails',
            'BagOfTests/CoinTossingUITests/testResultIsHeads'
          ]
        )
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(%r{path/to/output/directory/report.junit}).and_return(true)
        allow(Fastlane::Actions::TestsFromJunitAction).to receive(:run).and_return(
          failed: ['BagOfTests/CoinTossingUITests/testResultIsTails']
        )
        helper.after_testrun(FastlaneCore::Interface::FastlaneTestFailure.new('test failure'))
        expect(helper.scan_options).to include(
          only_testing: ['BagOfTests/CoinTossingUITests/testResultIsTails']
        )
      end

      it 'continually increments the report suffix for html and junit files' do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(%r{path/to/output/directory/coinTossResult(-\d)?.junit}).and_return(true)
        allow(Fastlane::Actions::TestsFromJunitAction).to receive(:run).and_return(
          failed: ['BagOfTests/CoinTossingUITests/testResultIsTails']
        )

        helper = RetryingScanHelper.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          output_directory: File.absolute_path('./path/to/output/directory'),
          only_testing: [
            'BagOfTests/CoinTossingUITests/testResultIsTails',
            'BagOfTests/CoinTossingUITests/testResultIsHeads'
          ],
          output_files: 'coinTossResult.html,coinTossResult.junit',
          output_types: 'html,junit',
        )
        scan_options = helper.scan_options
        expect(scan_options.keys).to include(:output_files, :output_types)
        expect(scan_options[:output_files].split(',')).to include(
          'coinTossResult.html', 'coinTossResult.junit'
        )
        
        helper.after_testrun(FastlaneCore::Interface::FastlaneTestFailure.new('test failure'))

        scan_options = helper.scan_options
        expect(scan_options.keys).to include(:output_files, :output_types)
        expect(scan_options[:output_files].split(',')).to include(
          'coinTossResult-2.html', 'coinTossResult-2.junit'
        )

        helper.after_testrun(FastlaneCore::Interface::FastlaneTestFailure.new('test failure'))

        scan_options = helper.scan_options
        expect(scan_options.keys).to include(:output_files, :output_types)
        expect(scan_options[:output_files].split(',')).to include(
          'coinTossResult-3.html', 'coinTossResult-3.junit'
        )
      end

      it 'continually increments the report suffix for batched html and junit files' do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(%r{.*/path/to/output/directory/BagOfTests-batch-3/coinTossResult(-\d)?.junit}).and_return(true)
        allow(Fastlane::Actions::TestsFromJunitAction).to receive(:run).and_return(
          failed: ['BagOfTests/CoinTossingUITests/testResultIsTails']
        )

        helper = RetryingScanHelper.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          output_directory: File.absolute_path('./path/to/output/directory/BagOfTests-batch-3'),
          only_testing: [
            'BagOfTests/CoinTossingUITests/testResultIsTails',
            'BagOfTests/CoinTossingUITests/testResultIsHeads'
          ],
          output_files: 'coinTossResult.html,coinTossResult.junit',
          output_types: 'html,junit',
          batch: 3,
          batch_count: 2
        )
        scan_options = helper.scan_options
        expect(scan_options.keys).to include(:output_files, :output_types)
        expect(scan_options[:output_files].split(',')).to include(
          'coinTossResult.html', 'coinTossResult.junit'
        )
        
        helper.after_testrun(FastlaneCore::Interface::FastlaneTestFailure.new('test failure'))

        scan_options = helper.scan_options
        expect(scan_options.keys).to include(:output_files, :output_types)
        expect(scan_options[:output_files].split(',')).to include(
          'coinTossResult-2.html', 'coinTossResult-2.junit'
        )

        helper.after_testrun(FastlaneCore::Interface::FastlaneTestFailure.new('test failure'))

        scan_options = helper.scan_options
        expect(scan_options.keys).to include(:output_files, :output_types)
        expect(scan_options[:output_files].split(',')).to include(
          'coinTossResult-3.html', 'coinTossResult-3.junit'
        )
      end
 
      it 'continually increments the report suffix for json' do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(%r{path/to/output/directory/report(-\d)?.xml}).and_return(true)
        allow(Fastlane::Actions::TestsFromJunitAction).to receive(:run).and_return(
          failed: ['BagOfTests/CoinTossingUITests/testResultIsTails']
        )

        helper = RetryingScanHelper.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          output_directory: File.absolute_path('./path/to/output/directory'),
          only_testing: [
            'BagOfTests/CoinTossingUITests/testResultIsTails',
            'BagOfTests/CoinTossingUITests/testResultIsHeads'
          ],
          output_files: 'coinTossResult.json',
          output_types: 'json',
        )
        
        json_files = []
        allow(ENV).to receive(:[]=) do |k, v|
          json_files << v if k == 'XCPRETTY_JSON_FILE_OUTPUT'
        end

        (1..3).each do
          helper.before_testrun
          helper.after_testrun(FastlaneCore::Interface::FastlaneTestFailure.new('test failure'))
        end
        absolute_output_directory = File.absolute_path('./path/to/output/directory')
        expect(json_files).to include(
          File.join(absolute_output_directory, 'coinTossResult.json'),
          File.join(absolute_output_directory, 'coinTossResult-2.json'),
          File.join(absolute_output_directory, 'coinTossResult-3.json')
        )
      end

      it 'has the correct result_bundle option' do
        helper = RetryingScanHelper.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          output_directory: File.absolute_path('./path/to/output/directory'),
          result_bundle: true
        )
        expect(helper.scan_options[:result_bundle]).to be_truthy
        helper = RetryingScanHelper.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          output_directory: File.absolute_path('./path/to/output/directory')
        )
        expect(helper.scan_options[:result_bundle]).to be_falsey
      end

      it 'has the correct buildlog_path option' do
        helper = RetryingScanHelper.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          output_directory: File.absolute_path('./path/to/output/directory'),
          buildlog_path: './path/to/output/build_log/directory'
        )
        expect(helper.scan_options[:buildlog_path]).to eq('./path/to/output/build_log/directory')
      end

      it 'raises an exception if given :device or :devices' do
        expect {
          RetryingScanHelper.new(
            derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
            output_directory: File.absolute_path('./path/to/output/directory'),
            device: 'iPhone 6'
          )
        }.to(
          raise_error(ArgumentError) do |error|
            expect(error.message).to match("Do not use the :device or :devices option. Instead use the :destination option.")
          end
        )
        expect {
          RetryingScanHelper.new(
            derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
            output_directory: File.absolute_path('./path/to/output/directory'),
            devices: ['iPhone 6', 'iPad Air']
          )
        }.to(
          raise_error(ArgumentError) do |error|
            expect(error.message).to match("Do not use the :device or :devices option. Instead use the :destination option.")
          end
        )
      end

      it 'has the correct destination option' do
        helper = RetryingScanHelper.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          output_directory: File.absolute_path('./path/to/output/directory'),
          destination: ['platform=iOS Simulator,id=0D312041-2D60-4221-94CC-3B0040154D74']
        )
        expect(helper.scan_options[:destination]).to eq(['platform=iOS Simulator,id=0D312041-2D60-4221-94CC-3B0040154D74'])
      end

      it 'has the correct scheme option' do
        helper = RetryingScanHelper.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          output_directory: File.absolute_path('./path/to/output/directory'),
          scheme: 'Thundercats'
        )
        expect(helper.scan_options[:scheme]).to eq('Thundercats')
      end

      it 'has the correct code_coverage option on the first run' do
        helper = RetryingScanHelper.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          output_directory: File.absolute_path('./path/to/output/directory'),
          code_coverage: true
        )
        expect(helper.scan_options[:code_coverage]).to eq(true)
      end

      it 'does not have code_coverage after runs that have test failures' do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(%r{.*/path/to/output/directory/report\.junit}).and_return(true)
        allow(Fastlane::Actions::TestsFromJunitAction).to receive(:run).and_return(
          failed: ['BagOfTests/CoinTossingUITests/testResultIsTails']
        )
        
        helper = RetryingScanHelper.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          output_directory: File.absolute_path('./path/to/output/directory'),
          code_coverage: true
        )
        helper.after_testrun(FastlaneCore::Interface::FastlaneTestFailure.new('test failure'))
        expect(helper.scan_options).not_to have_key(:code_coverage)
      end

      it 'sends junit test_run info to the call back after a success' do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(%r{.*/path/to/output/directory/report\.junit}).and_return(true)
        allow(Fastlane::Actions::TestsFromJunitAction).to receive(:run).and_return(
          passing: ['BagOfTests/CoinTossingUITests/testResultIsTails'],
          failed: []
        )
        
        actual_testrun_info = {}
        test_run_block = lambda do |testrun_info|
          actual_testrun_info = testrun_info
        end

        helper = RetryingScanHelper.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          output_directory: File.absolute_path('./path/to/output/directory'),
          testrun_completed_block: test_run_block
        )
        helper.after_testrun
        expect(actual_testrun_info).to include(
          failed: [],
          passing: ['BagOfTests/CoinTossingUITests/testResultIsTails'],
          batch: 1,
          try_count: 1,
          report_filepath: File.absolute_path('./path/to/output/directory/report.junit')
        )
      end

      it 'sends junit test_run info to the call back after a test failure' do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(%r{.*/path/to/output/directory/report(-\d)?\.junit}).and_return(true)
        allow(Fastlane::Actions::TestsFromJunitAction).to receive(:run).and_return(
          passing: [],
          failed: ['BagOfTests/CoinTossingUITests/testResultIsTails']
        )
        
        actual_testrun_info = {}
        test_run_block = lambda do |testrun_info|
          actual_testrun_info = testrun_info
        end

        helper = RetryingScanHelper.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          output_directory: File.absolute_path('./path/to/output/directory'),
          testrun_completed_block: test_run_block
        )
        helper.after_testrun(FastlaneCore::Interface::FastlaneTestFailure.new('test failure'))
        helper.after_testrun(FastlaneCore::Interface::FastlaneTestFailure.new('test failure'))
        expect(actual_testrun_info).to include(
          failed: ['BagOfTests/CoinTossingUITests/testResultIsTails'],
          passing: [],
          batch: 1,
          try_count: 2,
          report_filepath: File.absolute_path('./path/to/output/directory/report-2.junit')
        )
      end

      it 'sends junit test_run info to the call back after a recoverable infrastructure failure' do
        session_log_io = StringIO.new('Test operation failure: Test runner exited before starting test execution')
        allow(session_log_io).to receive(:stat).and_return(OpenStruct.new(size: session_log_io.size))
  
        allow(Dir).to receive(:glob)
                  .with(%r{.*AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr/Logs/Test/\*\.xcresult/\*_Test/Diagnostics/\*\*/Session-\*\.log})
                  .and_return(['A/B/C/Session-AtomicBoyUITests-Today.log'])

        allow(File).to receive(:open).with('A/B/C/Session-AtomicBoyUITests-Today.log').and_return(session_log_io)

        actual_testrun_info = {}
        test_run_block = lambda do |testrun_info|
          actual_testrun_info = testrun_info
        end

        helper = RetryingScanHelper.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          output_directory: File.absolute_path('./path/to/output/directory'),
          testrun_completed_block: test_run_block
        )
        helper.after_testrun(FastlaneCore::Interface::FastlaneBuildFailure.new('test failure'))
        expect(actual_testrun_info).to include(
          failed: nil,
          passing: nil,
          test_operation_failure: 'Test runner exited before starting test execution',
          batch: 1,
          try_count: 1,
          report_filepath: nil
        )
      end

      it 'sends junit test_run info to the call back after an unrecoverable infrastructure failure' do
        session_log_io = StringIO.new('Test operation failure: Launch session expired before checking in')
        allow(session_log_io).to receive(:stat).and_return(OpenStruct.new(size: session_log_io.size))
  
        allow(Dir).to receive(:glob)
                  .with(%r{.*AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr/Logs/Test/\*\.xcresult/\*_Test/Diagnostics/\*\*/Session-\*\.log})
                  .and_return(['A/B/C/Session-AtomicBoyUITests-Today.log'])

        allow(File).to receive(:open).with('A/B/C/Session-AtomicBoyUITests-Today.log').and_return(session_log_io)

        actual_testrun_info = {}
        test_run_block = lambda do |testrun_info|
          actual_testrun_info = testrun_info
        end

        helper = RetryingScanHelper.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          output_directory: File.absolute_path('./path/to/output/directory'),
          testrun_completed_block: test_run_block
        )
        expect {
          helper.after_testrun(FastlaneCore::Interface::FastlaneBuildFailure.new('no check-in'))
        }.to(
          raise_error(FastlaneCore::Interface::FastlaneBuildFailure) do |error|
            expect(error.message).to match("no check-in")
          end
        )
        expect(actual_testrun_info).to include(
          failed: nil,
          passing: nil,
          test_operation_failure: 'Launch session expired before checking in',
          batch: 1,
          try_count: 1,
          report_filepath: nil
        )
      end
    end
  end
end

