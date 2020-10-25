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
          name: 'iPad Pro Clone 1 TestCenter::Helper::MultiScanManager::SimulatorHelper<123>',
          udid: 'C3C9E104-8A3C-4BD0-9285-2112D3F783FA',
          state: 'Shutdown',
          os_version: '13.1'
        ),
        OpenStruct.new(
          name: 'iPad Pro Clone 2 TestCenter::Helper::MultiScanManager::SimulatorHelper<456>',
          udid: 'AD6DBBF5-0A71-433C-8763-4BF0A21E0C67',
          state: 'Shutdown',
          os_version: '13.1'
        ),
        OpenStruct.new(
          name: 'iPad Pro Clone 3 TestCenter::Helper::MultiScanManager::SimulatorHelper<789>',
          udid: 'D9330B65-E30B-49A5-97A9-89199E917D6C',
          state: 'Shutdown',
          os_version: '13.1'
        ),
        OpenStruct.new(
          name: 'iPad Pro Clone 4 TestCenter::Helper::MultiScanManager::SimulatorHelper<147>',
          udid: '2C6B6BC5-7AE0-47CF-B874-32212BFB9684',
          state: 'Shutdown',
          os_version: '13.1'
        ),
        OpenStruct.new(
          name: 'iPad Pro (12.9-inch) (2nd generation)',
          udid: '0D312041-2D60-4221-94CC-3B0040154D74',
          state: 'Shutdown',
          os_version: '13.1'
        )
      ]
      allow(FastlaneCore::DeviceManager).to receive(:simulators).and_return(@mocked_simulators)
    end

    describe 'setup' do
      it 'deletes pre-existing simulator clones when :pre_delete_cloned_simulators' do          
        helper = SimulatorHelper.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          project: File.absolute_path('AtomicBoy/AtomicBoy.xcodeproj'),
          scheme: 'Atlas',
          parallel_testrun_count: 4
        )
        expect(helper).to receive(:delete_multi_scan_cloned_simulators)
        helper.setup
      end
      it 'does not delete pre-existing simulator clones when :pre_delete_cloned_simulators is false' do          
        helper = SimulatorHelper.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          project: File.absolute_path('AtomicBoy/AtomicBoy.xcodeproj'),
          scheme: 'Atlas',
          parallel_testrun_count: 4,
          pre_delete_cloned_simulators: false
        )
        expect(helper).not_to receive(:delete_multi_scan_cloned_simulators)
        helper.setup
      end
    end

    describe '#parallel_destination_simulators' do
      describe 'with :reuse_simulators_for_parallel_testruns' do
        it 'clones all the simulator it needs' do
          helper = SimulatorHelper.new(
            parallel_testrun_count: 4,
            reuse_simulators_for_parallel_testruns: true
          )
          allow(helper).to receive(:find_matching_destination_simulators)
                       .and_return([])

          expect(helper).to receive(:clone_destination_simulators).with(4).and_return([1,2,3,4])
          helper.parallel_destination_simulators
        end
    
        it 'uses 2 preexisting simulators, and clones 2 simulators it needs' do
          helper = SimulatorHelper.new(
            parallel_testrun_count: 4,
            reuse_simulators_for_parallel_testruns: true
          )
          allow(helper).to receive(:find_matching_destination_simulators)
                       .and_return([1,2])

          expect(helper).to receive(:clone_destination_simulators).with(2).and_return([3,4])
          helper.parallel_destination_simulators
        end

        
        it 'uses all 4 preexisting simulators' do
          helper = SimulatorHelper.new(
            parallel_testrun_count: 4,
            reuse_simulators_for_parallel_testruns: true
          )
          allow(helper).to receive(:find_matching_destination_simulators)
                       .and_return([1,2, 3, 4])

          expect(helper).not_to receive(:clone_destination_simulators)
          helper.parallel_destination_simulators
        end
      end
    end

    describe '#find_matching_destination_simulators' do
      it 'finds 4 matching simulators' do
        @mocked_scan_config[:destination] = @mocked_scan_config[:destination]
        allow(::Scan).to receive(:config).and_return(@mocked_scan_config)

        allow(FastlaneCore::DeviceManager).to receive(:simulators).and_return(
          [
            OpenStruct.new(
              name: 'iPad Pro (12.9-inch) (2nd generation) Clone 2 TestCenter::Helper::MultiScanManager::SimulatorHelper<123>',
              udid: 'empire strikes back',
              state: 'Shutdown',
              os_version: '13.1'
            ),
            OpenStruct.new(
              name: 'iPad Pro (12.9-inch) (2nd generation) Clone 3 TestCenter::Helper::MultiScanManager::SimulatorHelper<123>',
              udid: 'donnie darko',
              state: 'Shutdown',
              os_version: '13.1'
            ),
            OpenStruct.new(
              name: 'iPad Pro (12.9-inch) (2nd generation) Clone 1 TestCenter::Helper::MultiScanManager::SimulatorHelper<123>',
              udid: 'in the mouth of madness',
              state: 'Shutdown',
              os_version: '13.1'
            ),
            OpenStruct.new(
              name: 'iPad Pro (12.9-inch) (2nd generation) Clone 1 TestCenter::Helper::MultiScanManager::SimulatorHelper<123>',
              udid: 'angel heart',
              state: 'Shutdown',
              os_version: '13.1'
            ),
            OpenStruct.new(
              name: 'iPad Pro (12.9-inch) (2nd generation)',
              udid: '0D312041-2D60-4221-94CC-3B0040154D74',
              state: 'Shutdown',
              os_version: '13.1'
            )
          ]
        )
        helper = SimulatorHelper.new(
          parallel_testrun_count: 4,
          reuse_simulators_for_parallel_testruns: true
        )
        found_simulators = helper.find_matching_destination_simulators(4)
        expect(found_simulators.map(&:udid)).to match_array(
          [
            'empire strikes back',
            'donnie darko',
            'in the mouth of madness',
            'angel heart' 
          ]
        )
      end
      
      it 'finds only 2 matching simulators' do
        @mocked_scan_config[:destination] = @mocked_scan_config[:destination]
        allow(::Scan).to receive(:config).and_return(@mocked_scan_config)

        allow(FastlaneCore::DeviceManager).to receive(:simulators).and_return(
          [
            OpenStruct.new(
              name: 'iPad Clone 2 TestCenter::Helper::MultiScanManager::SimulatorHelper<123>',
              udid: 'empire strikes back',
              state: 'Shutdown',
              os_version: '13.1'
            ),
            OpenStruct.new(
              name: 'iPad Pro (12.9-inch) (2nd generation) Clone 3 TestCenter::Helper::MultiScanManager::SimulatorHelper<123>',
              udid: 'donnie darko',
              state: 'Shutdown',
              os_version: '12.1'
            ),
            OpenStruct.new(
              name: 'iPad Pro (12.9-inch) (2nd generation) Clone 1 TestCenter::Helper::MultiScanManager::SimulatorHelper<123>',
              udid: 'in the mouth of madness',
              state: 'Shutdown',
              os_version: '13.1'
            ),
            OpenStruct.new(
              name: 'iPad Pro (12.9-inch) (2nd generation) Clone 1 TestCenter::Helper::MultiScanManager::SimulatorHelper<123>',
              udid: 'angel heart',
              state: 'Shutdown',
              os_version: '13.1'
            ),
            OpenStruct.new(
              name: 'iPad Pro (12.9-inch) (2nd generation)',
              udid: '0D312041-2D60-4221-94CC-3B0040154D74',
              state: 'Shutdown',
              os_version: '13.1'
            )
          ]
        )
        helper = SimulatorHelper.new(
          parallel_testrun_count: 4,
          reuse_simulators_for_parallel_testruns: true
        )
        found_simulators = helper.find_matching_destination_simulators(4)
        expect(found_simulators.map(&:udid)).to match_array(
          [
            'in the mouth of madness',
            'angel heart' 
          ]
        )
      end

      it 'does not find any matching simulators' do
        @mocked_scan_config[:destination] = @mocked_scan_config[:destination]
        allow(::Scan).to receive(:config).and_return(@mocked_scan_config)

        allow(FastlaneCore::DeviceManager).to receive(:simulators).and_return(
          [
            OpenStruct.new(
              name: 'iPad Clone 2 TestCenter::Helper::MultiScanManager::SimulatorHelper<123>',
              udid: 'empire strikes back',
              state: 'Shutdown',
              os_version: '13.1'
            ),
            OpenStruct.new(
              name: 'iPad Pro (12.9-inch) (2nd generation) Clone 3 TestCenter::Helper::MultiScanManager::SimulatorHelper<123>',
              udid: 'donnie darko',
              state: 'Shutdown',
              os_version: '12.1'
            ),
            OpenStruct.new(
              name: 'iPad Pro (12.9-inch) (2nd generation)',
              udid: 'in the mouth of madness',
              state: 'Shutdown',
              os_version: '13.1'
            ),
            OpenStruct.new(
              name: 'iPad Pro (12.9-inch) (2nd generation) Clone 1 TestCenter::Helper::MultiScanManager::SimulatorHelper<123>',
              udid: 'angel heart',
              state: 'Shutdown',
              os_version: '11.1'
            ),
            OpenStruct.new(
              name: 'iPad Pro (12.9-inch) (2nd generation)',
              udid: '0D312041-2D60-4221-94CC-3B0040154D74',
              state: 'Shutdown',
              os_version: '13.1'
            )
          ]
        )
        helper = SimulatorHelper.new(
          parallel_testrun_count: 4,
          reuse_simulators_for_parallel_testruns: true
        )
        found_simulators = helper.find_matching_destination_simulators(4)
        expect(found_simulators).to match_array([])
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
        
        result = helper.clone_destination_simulators(4)
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
        result = helper.clone_destination_simulators(4)
        expect(result).to eq(cloned_simulators.map { |s| [ s ] })
      end

      it 'creates multiple cloned simulators for each batch' do
        @mocked_scan_config[:destination] = @mocked_scan_config[:destination] << 'platform=iOS Simulator,id=C3C9E104-8A3C-4BD0-9285-2112D3F783FA'
        allow(::Scan).to receive(:config).and_return(@mocked_scan_config)
        @mocked_simulators.each do |mocked_simulator|
          allow(mocked_simulator).to receive(:rename)
        end

        helper = SimulatorHelper.new(
          derived_data_path: 'AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr',
          project: File.absolute_path('AtomicBoy/AtomicBoy.xcodeproj'),
          scheme: 'Atlas',
          parallel_testrun_count: 2,
          pre_delete_cloned_simulators: false
        )
        cloned_simulators = helper.clone_destination_simulators(2)
        expect(cloned_simulators[0].size).to eq(2)
        expect(cloned_simulators[1].size).to eq(2)
      end

    end

    describe '.call_simulator_started_callback' do
      it 'returns early if the callback option is not set' do
        devices = [ OpenStruct.new ]

        expect(devices).not_to receive(:each)

        SimulatorHelper.call_simulator_started_callback(
          { platform: :ios_simulator },
          devices
        ) 
      end

      it 'returns early if the platform is not iOS Simulator' do
        devices = [ OpenStruct.new ]

        expect(devices).not_to receive(:each)

        SimulatorHelper.call_simulator_started_callback(
          { platform: :macos },
          devices
        )
      end

      it 'sends the device udid to the callback for each iOS Simulator' do
        devices = [
          OpenStruct.new(udid: '123'),
          OpenStruct.new(udid: 'ABC')
        ]

        callback = OpenStruct.new

        expect(callback).to receive(:call).with('123')
        expect(callback).to receive(:call).with('ABC')

        SimulatorHelper.call_simulator_started_callback(
          {
            platform: :ios_simulator,
            simulator_started_callback: callback
          },
          devices
        )

      end
    end
  end
end
