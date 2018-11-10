describe TestCenter::Helper::RetryingScan do
  skip 'simulator_manager' do
    describe 'batch_count is 1, one device' do
      before(:each) do
        device = OpenStruct.new(
          name: 'iPhone 5s',
          udid: 'B56B326E-0060-46F0-90EB-EFD433A03232',
          os_type: 'iOS',
          os_version: '98.0',
          ios_version: '98.0',
          state: 'Shutdown',
          is_simulator: true
        )
        allow(Scan::DetectValues).to receive(:detect_simulator).and_return([device])
      end

      class SingleBatch
        include SimulatorManager

        def initialize
          @batch_count = 1
          @scan_options = {
            devices: ['iPhone 5s (98.0)']
          }
          super()
        end
      end

      class SingleBatchMultiSimulators
        include SimulatorManager

        def initialize
          @batch_count = 1
          @scan_options = {
            devices: ['iPhone 5s (98.0)', 'iPhone 5s (12.0)']
          }
          super()
        end
      end

      describe '#setup_simulators' do
        it 'does not clone any simulator devices' do
          single = SingleBatch.new
          expect(SingleBatch).not_to receive(:`)
          single.setup_simulators
        end
      end

      describe '#devices' do
        before(:each) do
          @singlebatch_one_device = SingleBatch.new
          @singlebatch_one_device.setup_simulators

          @singlebatch_two_devices = SingleBatchMultiSimulators.new
          @singlebatch_two_devices.setup_simulators
        end

        it 'returns only the original device for batch 1' do
          expect(@singlebatch_one_device.devices(1)).to eq(['iPhone 5s (98.0)'])
        end
        it 'returns only the original devices for batch 1' do
          expect(@singlebatch_two_devices.devices(1)).to eq(['iPhone 5s (98.0)', 'iPhone 5s (12.0)'])
        end
        it 'raises an exception for \'batch 99\'' do
          expect { @singlebatch_one_device.devices(99) }.to(
            raise_error(Exception) do |error|
              expect(error.message).to match("Error: impossible to request devices for batch 99, there are only 1 set(s) of simulators")
            end
          )
        end
      end
    end

    describe 'batch_count is 2' do
      before(:each) do
        class OpenStruct
          def rename(new_name)
            self.name = new_name
          end
        end

        @device = OpenStruct.new(
          name: 'iPhone 5s',
          udid: 'B56B326E-0060-46F0-90EB-EFD433A03232',
          os_type: 'iOS',
          os_version: '98.0',
          ios_version: '98.0',
          state: 'Shutdown',
          is_simulator: true
        )
        @device2 = OpenStruct.new(
          name: 'iPhone 5s',
          udid: 'B56B326E-0060-46F0-90EB-EFD433A03232',
          os_type: 'iOS',
          os_version: '12.0',
          ios_version: '12.0',
          state: 'Shutdown',
          is_simulator: true
        )

      end

      class MultiBatch
        include SimulatorManager

        def initialize
          @batch_count = 2
          @scan_options = {
            devices: ['iPhone 5s (98.0)']
          }
          super()
        end
      end

      class MultiBatchMultiSimulators
        include SimulatorManager

        def initialize
          @batch_count = 2
          @scan_options = {
            devices: ['iPhone 5s (98.0)', 'iPhone 5s (12.0)']
          }
          super()
        end
      end

      describe '#devices' do
        before(:each) do
          @multi = MultiBatch.new
          allow(Scan::DetectValues).to receive(:detect_simulator).and_return([@device])
          @multi.setup_simulators

          @multimulti = MultiBatchMultiSimulators.new
          allow(Scan::DetectValues).to receive(:detect_simulator).and_return([@device, @device2])
          @multimulti.setup_simulators
        end

        it 'returns cloned devices for batch 1, one device' do
          expect(@multi.devices(1)).to eq(["iPhone 5s-batchclone-1 (98.0)"])
        end

        it 'returns cloned devices for batch 2, one device' do
          expect(@multi.devices(2)).to eq(["iPhone 5s-batchclone-2 (98.0)"])
        end

        it 'returns cloned devices for batch 1, two devices' do
          expect(@multimulti.devices(1)).to eq(["iPhone 5s-batchclone-1 (98.0)", "iPhone 5s-batchclone-1 (12.0)"])
        end

        it 'returns cloned devices for batch 2, two devices' do
          expect(@multimulti.devices(2)).to eq(["iPhone 5s-batchclone-2 (98.0)", "iPhone 5s-batchclone-2 (12.0)"])
        end

        it 'raises an exception for \'batch 99\'' do
          expect { @multi.devices(99) }.to(
            raise_error(Exception) do |error|
              expect(error.message).to match("Error: impossible to request devices for batch 99, there are only 2 set(s) of simulators")
            end
          )
        end
      end
    end
  end
end
