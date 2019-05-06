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

      it 'renames the resultant test bundle' do
        allow(Dir).to receive(:glob).with(%r{/.*/path/to/output/directory/.*\.test_result}).and_return(['./AtomicDragon.test_result', './AtomicDragon-99.test_result'])
        allow(FileUtils).to receive(:mkdir_p)
        helper = RetryingScanHelper.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          output_directory: './path/to/output/directory',
          result_bundle: true
        )
        expect(FileUtils).to receive(:mv).with('./AtomicDragon.test_result', './AtomicDragon-1.test_result')
        helper.after_testrun
        expect(FileUtils).to receive(:mv).with('./AtomicDragon.test_result', './AtomicDragon-2.test_result')
        helper.after_testrun
        expect(FileUtils).to receive(:mv).with('./AtomicDragon.test_result', './AtomicDragon-3.test_result')
        helper.after_testrun
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
    end
  end
end

# describe 'scan_helper' do
#   describe 'before a scan' do
#     describe 'scan_options' do
#       skip 'has the output directory'
#       skip 'has the test_result option'
#       skip 'has the build log path'
#       skip 'has the desintation for sims and not device(s)'
#       skip 'has the scheme'
#       skip 'has code coverage'
#     end
#   end

#   describe 'after a scan' do
#     skip 'sends info about the last test run to the test_run callback'
#     skip 'updates the reportnamer
#   end

# end
