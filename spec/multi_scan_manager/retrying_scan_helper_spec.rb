require 'pry-byebug'

describe TestCenter::Helper::MultiScanManager do
  describe 'retrying_scan_helper', refactor_retrying_scan:true do

    RetryingScanHelper ||= TestCenter::Helper::MultiScanManager::RetryingScanHelper
    before(:each) do
      allow(Dir).to receive(:glob).and_call_original
      allow(File).to receive(:open).and_call_original
      allow(FileUtils).to receive(:rm_rf).and_call_original
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
        byebug
        helper.after_testrun
        expect(FileUtils).to receive(:mv).with('./AtomicDragon.test_result', './AtomicDragon-2.test_result')
        helper.after_testrun
        expect(FileUtils).to receive(:mv).with('./AtomicDragon.test_result', './AtomicDragon-3.test_result')
        helper.after_testrun
      end
    end
  end
end

# describe 'scan_helper' do
#   describe 'before a scan' do
#     skip 'clears out pre-existing test bundles before scan'
#     skip 'sets up JSON xcpretty output option'
#     skip 'resets the simulators'
#     skip 'gets the scan options'

#     describe 'the options' do
#     end

#   end

#   describe 'after a scan' do
#     skip 'updates the test bundle name after a scan'
#     skip 'resets the JSON xcpretty output option'
#     skip 'sends info about the last test run to the test_run callback'
#     skip 'updates the reportnamer'
#   end

# end
