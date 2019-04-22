require 'pry-byebug'

describe TestCenter::Helper::MultiScanManager do
  describe 'simulator_helper', simulator_helper:true do
    SimulatorHelper ||= TestCenter::Helper::MultiScanManager::SimulatorHelper

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
          udid: 'C3C9E104-8A3C-4BD0-9285-2112D3F783FA'
        ),
        OpenStruct.new(
          name: 'iPad Pro Clone 2 for TestCenter::Helper::MultiScanManager::SimulatorHelper<456>',
          udid: 'AD6DBBF5-0A71-433C-8763-4BF0A21E0C67'
        ),
        OpenStruct.new(
          name: 'iPad Pro Clone 3 for TestCenter::Helper::MultiScanManager::SimulatorHelper<789>',
          udid: 'D9330B65-E30B-49A5-97A9-89199E917D6C'
        ),
        OpenStruct.new(
          name: 'iPad Pro Clone 4 for TestCenter::Helper::MultiScanManager::SimulatorHelper<147>',
          udid: '2C6B6BC5-7AE0-47CF-B874-32212BFB9684'
        ),
        OpenStruct.new(
          name: 'iPad Pro (12.9-inch) (2nd generation)',
          udid: '0D312041-2D60-4221-94CC-3B0040154D74'
        )
      ]
      allow(FastlaneCore::DeviceManager).to receive(:simulators).and_return(@mocked_simulators)
    end

    describe 'setup' do
      it 'does not set up the iOS destination if it is set' do          
        helper = SimulatorHelper.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          project: File.absolute_path('AtomicBoy/AtomicBoy.xcodeproj'),
          scheme: 'Atlas',
          parallelize: true
        )
        allow(helper).to receive(:delete_multi_scan_cloned_simulators)
        expect(FastlaneCore::Configuration).not_to receive(:create)
        helper.setup
      end

      it 'sets up the "iOS destination" if it is not set' do
        allow(FastlaneCore::Configuration).to receive(:create).and_return(@mocked_scan_config)
        allow(::Scan.config).to receive(:_values).and_return({})

        helper = SimulatorHelper.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          project: File.absolute_path('AtomicBoy/AtomicBoy.xcodeproj'),
          scheme: 'Atlas',
          parallelize: true
        )
        allow(helper).to receive(:delete_multi_scan_cloned_simulators)
        allow(helper).to receive(:delete_multi_scan_cloned_simulators)
        allow(helper).to receive(:clone_destination_simulators)

        
        expect(::Scan).to receive(:config=).with(@mocked_scan_config)
        helper.setup
      end

      it 'deletes cloned simulators' do
        allow(::Scan).to receive(:config).and_return(@mocked_scan_config)
        
        helper = SimulatorHelper.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          project: File.absolute_path('AtomicBoy/AtomicBoy.xcodeproj'),
          scheme: 'Atlas',
          parallelize: true
        )
        *cloned_simulators, _ = @mocked_simulators
        cloned_simulators.each do |cloned_simulator|
          expect(cloned_simulator).to receive(:delete)
        end
        helper.setup
      end

      it 'creates cloned simulators' do
        allow(::Scan).to receive(:config).and_return(@mocked_scan_config)
        helper = SimulatorHelper.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          project: File.absolute_path('AtomicBoy/AtomicBoy.xcodeproj'),
          scheme: 'Atlas',
          batch_count: 4,
          parallelize: true
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
          expect(cloned_simulators[index]).to receive(:rename).with(/iPad Pro Clone #{index} TestCenter::Helper::MultiScanManager::SimulatorHelper<\d+>/)
        end
        result = helper.clone_destination_simulators
        expect(result).to eq(cloned_simulators.map { |s| [ s ] })
      end
    end
  end
end
