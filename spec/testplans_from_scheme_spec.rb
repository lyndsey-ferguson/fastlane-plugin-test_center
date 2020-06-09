module Fastlane::Actions
  describe 'TestplansFromSchemeAction' do
    describe '::available_options' do
      it 'raises an error if there is no :xcodeproj or :workspace' do
        fastfile = "lane :test do
          testplans_from_scheme(
            xcodeproj: 'path/to/non-existent.xcodeproj',
            scheme: 'Oz'
          )
        end"

        expect { Fastlane::FastFile.new.parse(fastfile).runner.execute(:test) }.to(
          raise_error(FastlaneCore::Interface::FastlaneError) do |error|
            expect(error.message).to match(%r{Error: Xcode project '.*path/to/non-existent.xcodeproj' not found!})
          end
        )

        fastfile = "lane :test do
          testplans_from_scheme(
            workspace: 'path/to/non-existent.xcworkspace',
            scheme: 'Oz'
          )
        end"

        expect { Fastlane::FastFile.new.parse(fastfile).runner.execute(:test) }.to(
          raise_error(FastlaneCore::Interface::FastlaneError) do |error|
            expect(error.message).to match(%r{Error: Workspace file not found at path '.*path/to/non-existent.xcworkspace'})
          end
        )
      end
      it 'raises an error if the scheme is empty' do
        allow(Dir).to receive(:exist?).with(%r{.*path/to/non-existent.xcworkspace}).and_return(true)
        fastfile = "lane :test do
          testplans_from_scheme(
            workspace: 'path/to/non-existent.xcworkspace',
            scheme: ''
          )
        end"

        expect { Fastlane::FastFile.new.parse(fastfile).runner.execute(:test) }.to(
          raise_error(FastlaneCore::Interface::FastlaneError) do |error|
            expect(error.message).to match("Error: Xcode Scheme '' is not valid!")
          end
        )
      end
    end

    describe ':run' do
      it 'raises an error if the given scheme does not exist' do
        allow(Dir).to receive(:exist?).with(%r{.*path/to/pony.xcworkspace}).and_return(true)
        fastfile = "lane :test do
          testplans_from_scheme(
            workspace: 'path/to/pony.xcworkspace',
            scheme: 'HappyHelper'
          )
        end"
        expect { Fastlane::FastFile.new.parse(fastfile).runner.execute(:test) }.to(
          raise_error(FastlaneCore::Interface::FastlaneError) do |error|
            expect(error.message).to match("Error: cannot find any schemes in the Xcode workspace")
          end
        )
      end
      it 'returns a list of testplans if some exist' do
        allow(Dir).to receive(:exist?).with(%r{.*path/to/pony.xcworkspace}).and_return(true)
        fastfile = "lane :test do
          testplans_from_scheme(
            workspace: 'path/to/pony.xcworkspace',
            scheme: 'HappyHelper'
          )
        end"
        mock_scheme_filepaths = [
          'path/to/TestProject.xcodeproj/HappyHelper.xcscheme'
        ]
        allow(Fastlane::Actions::TestplansFromSchemeAction).to receive(:schemes_from_project).and_return(mock_scheme_filepaths)
        mock_scheme = OpenStruct.new
        allow(Xcodeproj::XCScheme).to receive(:new).and_return(mock_scheme)
        mock_test_action = OpenStruct.new(
          testables: [
            OpenStruct.new(
              buildable_references: [
                OpenStruct.new(
                  target_referenced_container: 'container:TestProject.xcodeproj'
                )
              ]
            )
          ]
        )
        allow(mock_scheme).to receive(:test_action).and_return(mock_test_action)
        mock_test_plans = [
          OpenStruct.new(
            target_referenced_container: 'container:testPlan1.xctestplan'
          ),
          OpenStruct.new(
            target_referenced_container: 'container:OldTestPlans/testPlan2.xctestplan'
          )
        ]
        allow(mock_test_action).to receive(:test_plans).and_return(mock_test_plans)
        result = Fastlane::FastFile.new.parse(fastfile).runner.execute(:test)
        expect(result[0]).to match(%r{path/to/testPlan1.xctestplan})
        expect(result[1]).to match(%r{path/to/OldTestPlans/testPlan2.xctestplan})
      end

      it 'returns an empty list if no testplans exist' do
        allow(Dir).to receive(:exist?).with(%r{.*path/to/pony.xcworkspace}).and_return(true)
        fastfile = "lane :test do
          testplans_from_scheme(
            workspace: 'path/to/pony.xcworkspace',
            scheme: 'HappyHelper'
          )
        end"
        mock_scheme_filepaths = [
          'path/to/HappyHelper.xcscheme'
        ]
        allow(Fastlane::Actions::TestplansFromSchemeAction).to receive(:schemes_from_project).and_return(mock_scheme_filepaths)
        mock_scheme = OpenStruct.new
        allow(Xcodeproj::XCScheme).to receive(:new).and_return(mock_scheme)
        mock_test_action = OpenStruct.new
        allow(mock_scheme).to receive(:test_action).and_return(mock_test_action)
        mock_test_plans = []
        allow(mock_test_action).to receive(:test_plans).and_return(mock_test_plans)
        result = Fastlane::FastFile.new.parse(fastfile).runner.execute(:test)
        expect(result).to eq([])
      end
    end
  end
end

