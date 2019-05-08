require 'pry-byebug'

describe TestCenter::Helper::MultiScanManager do
  describe 'retrying_scan_helper', refactor_retrying_scan:true do

    RetryingScanHelper ||= TestCenter::Helper::MultiScanManager::RetryingScanHelper
    before(:each) do
      allow(Dir).to receive(:glob).and_call_original
      allow(File).to receive(:open).and_call_original
      allow(FileUtils).to receive(:rm_rf).and_call_original
      @xcpretty_json_file_output = ENV['XCPRETTY_JSON_FILE_OUTPUT']
    end

    after(:each) do
      ENV['XCPRETTY_JSON_FILE_OUTPUT'] = @xcpretty_json_file_output
    end

    describe 'before_testrun' do
      it 'clears out pre-existing test bundles' do
        allow(Dir).to receive(:glob).with(%r{/.*/path/to/output/directory/.*\.test_result}).and_return(['./AtomicDragon.test_result'])
        helper = RetryingScanHelper.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          output_directory: './path/to/output/directory',
          result_bundle: true
        )
        expect(FileUtils).to receive(:rm_rf).with(['./AtomicDragon.test_result'])
        helper.before_testrun
      end

      describe 'scan_options' do
        
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
        helper = RetryingScanHelper.new({derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr'})
        
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
          reset_simulators: true
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
          output_directory: './path/to/output/directory',
          result_bundle: true
        )
        expect(FileUtils).to receive(:mv).with('./AtomicDragon.test_result', './AtomicDragon-1.test_result')
        helper.after_testrun(FastlaneCore::Interface::FastlaneTestFailure.new('test failure'))
        expect(FileUtils).to receive(:mv).with('./AtomicDragon.test_result', './AtomicDragon-2.test_result')
        helper.after_testrun(FastlaneCore::Interface::FastlaneTestFailure.new('test failure'))
        expect(FileUtils).to receive(:mv).with('./AtomicDragon.test_result', './AtomicDragon-3.test_result')
        helper.after_testrun(FastlaneCore::Interface::FastlaneTestFailure.new('test failure'))
      end

      it 'resets the JSON xcpretty output option' do
        ENV['XCPRETTY_JSON_FILE_OUTPUT'] = './original/path/to/output/directory/xcpretty.json'
        allow(ENV).to receive(:[]=).and_call_original
        helper = RetryingScanHelper.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          output_directory: './path/to/output/directory',
          output_types: 'json',
          output_files: 'report.json'
        )
        expect(ENV).to receive(:[]=).with('XCPRETTY_JSON_FILE_OUTPUT', './original/path/to/output/directory/xcpretty.json')
        helper.after_testrun
      end
    end

    describe 'scan_options' do
      it 'has the tests to be tested' do
        helper = RetryingScanHelper.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          only_testing: ['BagOfTests/CoinTossingUITests/testResultIsTails']
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
          parallelize: true
        )
        expect(helper.scan_options.keys).not_to include(:batch_count, :parallelize)
        expect(helper.scan_options.keys).to include(:derived_data_path, :only_testing)
      end
      
      it 'has only the failing tests' do
        helper = RetryingScanHelper.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          output_directory: './path/to/output/directory',
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
          output_directory: './path/to/output/directory',
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

      it 'continually increments the report suffix for json' do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(%r{path/to/output/directory/report(-\d)?.xml}).and_return(true)
        allow(Fastlane::Actions::TestsFromJunitAction).to receive(:run).and_return(
          failed: ['BagOfTests/CoinTossingUITests/testResultIsTails']
        )

        helper = RetryingScanHelper.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          output_directory: './path/to/output/directory',
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

        expect(json_files).to include(
          './path/to/output/directory/coinTossResult.json',
          './path/to/output/directory/coinTossResult-2.json', 
          './path/to/output/directory/coinTossResult-3.json'
        )
      end

      it 'has the correct output_directory' do
        helper = RetryingScanHelper.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          output_directory: './path/to/output/directory'
        )
        expect(helper.scan_options[:output_directory]).to eq('./path/to/output/directory')
      end

      it 'has the correct result_bundle option' do
        helper = RetryingScanHelper.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          output_directory: './path/to/output/directory',
          result_bundle: true
        )
        expect(helper.scan_options[:result_bundle]).to be_truthy
        helper = RetryingScanHelper.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          output_directory: './path/to/output/directory'
        )
        expect(helper.scan_options[:result_bundle]).to be_falsey
      end

      it 'has the correct buildlog_path option' do
        helper = RetryingScanHelper.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          output_directory: './path/to/output/directory',
          buildlog_path: './path/to/output/build_log/directory'
        )
        expect(helper.scan_options[:buildlog_path]).to eq('./path/to/output/build_log/directory')
      end

      it 'raises an exception if given :device or :devices' do
        expect {
          RetryingScanHelper.new(
            derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
            output_directory: './path/to/output/directory',
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
            output_directory: './path/to/output/directory',
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
          output_directory: './path/to/output/directory',
          destination: ['platform=iOS Simulator,id=0D312041-2D60-4221-94CC-3B0040154D74']
        )
        expect(helper.scan_options[:destination]).to eq(['platform=iOS Simulator,id=0D312041-2D60-4221-94CC-3B0040154D74'])
      end

      it 'has the correct scheme option' do
        helper = RetryingScanHelper.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          output_directory: './path/to/output/directory',
          scheme: 'Thundercats'
        )
        expect(helper.scan_options[:scheme]).to eq('Thundercats')
      end

      it 'has the correct code_coverage option on the first run' do
        helper = RetryingScanHelper.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          output_directory: './path/to/output/directory',
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
          output_directory: './path/to/output/directory',
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
          output_directory: './path/to/output/directory',
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
          output_directory: './path/to/output/directory',
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

      it 'sends junit test_run info to the call back after an infrastructure failure' do
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
          output_directory: './path/to/output/directory',
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
    end
  end
end

# describe 'scan_helper' do
#   describe 'before a scan' do
#     skip 'prints to the console a message that a test_run is being started'
#     skip 'prints to the console when a test_run has failures'
#     skip 'prints to the console when a test_run has potentially recoverable fatal failures'
#     skip 'prints to the console when a test_run has unrecoverable fatal failures'
#   end
#   describe 'after a scan' do
#     skip 'sends info about the last test run to the test_run callback'
#     skip 'updates the reportnamer
#   end

# end
