module TestCenter::Helper::MultiScanManager
  describe 'simulator_helper' do
    before(:each) do
      @mocked_scan_config = FastlaneCore::Configuration.create(
        Fastlane::Actions::ScanAction.available_options,
        {
          destination: ['platform=iOS Simulator,id=0D312041-2D60-4221-94CC-3B0040154D74']
        }
      )
      allow(::Scan).to receive(:config).and_return(@mocked_scan_config)
      @mocked_simulators = [
        OpenStruct.new(
          name: 'iPad Pro Clone 1 for TestCenter::Helper::MultiScanManager::SimulatorHelper<123>',
          udid: 'C3C9E104-8A3C-4BD0-9285-2112D3F783FA',
          state: 'Shutdown'
        ),
        OpenStruct.new(
          name: 'iPad Pro Clone 2 for TestCenter::Helper::MultiScanManager::SimulatorHelper<456>',
          udid: 'AD6DBBF5-0A71-433C-8763-4BF0A21E0C67',
          state: 'Shutdown'
        ),
        OpenStruct.new(
          name: 'iPad Pro Clone 3 for TestCenter::Helper::MultiScanManager::SimulatorHelper<789>',
          udid: 'D9330B65-E30B-49A5-97A9-89199E917D6C',
          state: 'Shutdown'
        ),
        OpenStruct.new(
          name: 'iPad Pro Clone 4 for TestCenter::Helper::MultiScanManager::SimulatorHelper<147>',
          udid: '2C6B6BC5-7AE0-47CF-B874-32212BFB9684',
          state: 'Shutdown'
        ),
        OpenStruct.new(
          name: 'iPad Pro (12.9-inch) (2nd generation)',
          udid: '0D312041-2D60-4221-94CC-3B0040154D74',
          state: 'Shutdown'
        )
      ]
      allow(FastlaneCore::DeviceManager).to receive(:simulators).and_return(@mocked_simulators)
    end

    describe 'setup' do
      it 'deletes pre-existing simulator clones' do          
        helper = SimulatorHelper.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          project: File.absolute_path('AtomicBoy/AtomicBoy.xcodeproj'),
          scheme: 'Atlas',
          parallel_testrun_count: 4
        )
        expect(helper).to receive(:delete_multi_scan_cloned_simulators)
        helper.setup
      end
    end
    describe '#clone_destination_simulators' do
      it 'shuts down running simulators before cloning' do
        allow(::Scan).to receive(:config).and_return(@mocked_scan_config)
        helper = SimulatorHelper.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          project: File.absolute_path('AtomicBoy/AtomicBoy.xcodeproj'),
          scheme: 'Atlas',
          batch_count: 4,
          parallel_testrun_count: 4
        )
        original_device = @mocked_simulators.last
        (0...4).each do |index|
          allow(original_device).to receive(:clone).and_return(@mocked_simulators[index])
          allow(@mocked_simulators[index]).to receive(:rename)
        end
        expect(original_device).to receive(:shutdown)
        
        result = helper.clone_destination_simulators
      end

      it 'creates cloned simulators' do
        allow(::Scan).to receive(:config).and_return(@mocked_scan_config)
        helper = SimulatorHelper.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          project: File.absolute_path('AtomicBoy/AtomicBoy.xcodeproj'),
          scheme: 'Atlas',
          batch_count: 4,
          parallel_testrun_count: 4
        )
        original_device = @mocked_simulators.last
        cloned_simulators = [
          OpenStruct.new,
          OpenStruct.new,
          OpenStruct.new,
          OpenStruct.new
        ]
        (0...4).each do |index|
          expect(original_device).to receive(:clone).and_return(cloned_simulators[index])
          expect(cloned_simulators[index]).to receive(:rename).with(/iPad Pro Clone #{index + 1} TestCenter::Helper::MultiScanManager::SimulatorHelper<\d+>/)
        end
        result = helper.clone_destination_simulators
        expect(result).to eq(cloned_simulators.map { |s| [ s ] })
      end
    end
  end
end
