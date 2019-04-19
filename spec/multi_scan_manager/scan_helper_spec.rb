require 'pry-byebug'

describe TestCenter::Helper::MultiScanManager do
  describe 'scan_helper', scan_helper:true do

    ScanHelper ||= TestCenter::Helper::MultiScanManager::ScanHelper
    before(:each) do
      allow(Dir).to receive(:glob).and_call_original
      allow(File).to receive(:open).and_call_original
    end

    describe 'before_all' do
    end

    describe 'after_each' do
      it 'raises if there is a random build failure' do
        helper = ScanHelper.new({derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr'})

        session_log_io = StringIO.new('Everything went wrong!')
        allow(session_log_io).to receive(:stat).and_return(OpenStruct.new(size: session_log_io.size))
  
        allow(Dir).to receive(:glob)
                  .with(%r{.*AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr/Logs/Test/\*\.xcresult/\*_Test/Diagnostics/\*\*/Session-\*\.log})
                  .and_return(['A/B/C/Session-AtomicBoyUITests-Today.log', 'D/E/F/Session-AtomicBoyUITests-Today.log'])
  
        allow(File).to receive(:mtime).with('A/B/C/Session-AtomicBoyUITests-Today.log').and_return(1)
        allow(File).to receive(:mtime).with('D/E/F/Session-AtomicBoyUITests-Today.log').and_return(2)
        allow(File).to receive(:open).with('D/E/F/Session-AtomicBoyUITests-Today.log').and_return(session_log_io)

        expect {
          helper.after_each(
            FastlaneCore::Interface::FastlaneBuildFailure.new('chaos')
          )
        }.to(
          raise_error(FastlaneCore::Interface::FastlaneBuildFailure) do |error|
            expect(error.message).to match("chaos")
          end
        )
      end

      it 'does not raise if there is a test runner early exit failure' do
        helper = ScanHelper.new({derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr'})
        
        session_log_io = StringIO.new('Test operation failure: Test runner exited before starting test execution')
        allow(session_log_io).to receive(:stat).and_return(OpenStruct.new(size: session_log_io.size))
  
        allow(Dir).to receive(:glob)
                  .with(%r{.*AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr/Logs/Test/\*\.xcresult/\*_Test/Diagnostics/\*\*/Session-\*\.log})
                  .and_return(['A/B/C/Session-AtomicBoyUITests-Today.log', 'D/E/F/Session-AtomicBoyUITests-Today.log'])
  
        allow(File).to receive(:mtime).with('A/B/C/Session-AtomicBoyUITests-Today.log').and_return(1)
        allow(File).to receive(:mtime).with('D/E/F/Session-AtomicBoyUITests-Today.log').and_return(2)
        allow(File).to receive(:open).with('D/E/F/Session-AtomicBoyUITests-Today.log').and_return(session_log_io)
        
        helper.after_each(FastlaneCore::Interface::FastlaneBuildFailure.new('test failure'))
      end
    end

    describe 'parallelized' do
      before(:each) do
        @mocked_scan_config = {
          destination: 'platform=iOS Simulator,id=0D312041-2D60-4221-94CC-3B0040154D74'
        }
      end

      describe 'before_all' do
        it 'does not set up the iOS destination if it is set' do
          allow_any_instance_of(ScanHelper).to receive(:delete_multi_scan_cloned_simulators)
          allow(::Scan).to receive(:config).and_return(@mocked_scan_config)

          helper = ScanHelper.new(
            {
              derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
              project: File.absolute_path('AtomicBoy/AtomicBoy.xcodeproj'),
              scheme: 'Atlas'
            },
            true
          )
          expect(FastlaneCore::Configuration).not_to receive(:create)
          helper.before_all
        end
  
        it 'sets up the "iOS destination" if it is not set' do
          allow_any_instance_of(ScanHelper).to receive(:delete_multi_scan_cloned_simulators)
          allow(FastlaneCore::Configuration).to receive(:create).and_return(@mocked_scan_config)

          helper = ScanHelper.new(
            {
              derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
              project: File.absolute_path('AtomicBoy/AtomicBoy.xcodeproj'),
              scheme: 'Atlas'
            },
            true
          )
          
          expect(::Scan).to receive(:config=).with(@mocked_scan_config)
          helper.before_all
        end

        it 'deletes cloned simulators' do
          allow(::Scan).to receive(:config).and_return(@mocked_scan_config)
          mocked_simulators = [
            OpenStruct.new(
              name: 'iPad Pro Clone 1 for TestCenter::Helper::MultiScanManager::ScanHelper<123>'
            ),
            OpenStruct.new(
              name: 'iPad Pro Clone 2 for TestCenter::Helper::MultiScanManager::ScanHelper<456>'
            ),
            OpenStruct.new(
              name: 'iPad Pro Clone 3 for TestCenter::Helper::MultiScanManager::ScanHelper<789>'
            ),
            OpenStruct.new(
              name: 'iPad Pro Clone 4 for TestCenter::Helper::MultiScanManager::ScanHelper<147>'
            )
          ]
          allow(FastlaneCore::DeviceManager).to receive(:simulators).and_return(mocked_simulators)
          helper = ScanHelper.new(
            {
              derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
              project: File.absolute_path('AtomicBoy/AtomicBoy.xcodeproj'),
              scheme: 'Atlas'
            },
            true
          )

          mocked_simulators.each do |mocked_simulator|
            expect(mocked_simulator).to receive(:delete)
          end
          helper.before_all
        end
      end
    end
  end
end
