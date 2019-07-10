module Fastlane::Actions
  describe 'QuitCoreSimulatorServiceAction' do
    describe '#run' do
      it 'does nothing if CoreSimulatorService is not running' do
        allow(Fastlane::Actions).to receive(:sh).and_return('')

        config = FastlaneCore::Configuration.create(
          QuitCoreSimulatorServiceAction.available_options,
          { }
        )
        result = QuitCoreSimulatorServiceAction.run(config)
        expect(result).to be_empty
      end

      it 'quits within 10 attempts' do
        mocked_launchctl_list_results = [ 'running', '' ]
        allow(Fastlane::Actions).to receive(:sh)
          .with(/launchctl list/, anything) do
            mocked_launchctl_list_results.shift
          end

        allow(Fastlane::Actions).to receive(:sh)
          .with(/launchctl remove/, anything)
          .and_return('launchctl remove')

        config = FastlaneCore::Configuration.create(
          QuitCoreSimulatorServiceAction.available_options,
          { }
        )
        allow(QuitCoreSimulatorServiceAction).to receive(:sleep)
        result = QuitCoreSimulatorServiceAction.run(config)
        expect(result).to eq(['launchctl remove'])
      end

      it 'crashes after 11 attempts' do
        allow(Fastlane::Actions).to receive(:sh)
          .with(/launchctl list/, anything)
          .and_return('running')

        allow(Fastlane::Actions).to receive(:sh)
          .with(/launchctl remove/, anything)
          .and_return('launchctl remove')

        config = FastlaneCore::Configuration.create(
          QuitCoreSimulatorServiceAction.available_options,
          { }
        )
        allow(QuitCoreSimulatorServiceAction).to receive(:sleep)

        expect { QuitCoreSimulatorServiceAction.run(config) }.to(
          raise_error(FastlaneCore::Interface::FastlaneCrash) do |error|
            expect(error.message).to match(/Unable to quit com\.apple\.CoreSimulator\.CoreSimulatorService/)
          end
        )
      end
    end
  end
end
