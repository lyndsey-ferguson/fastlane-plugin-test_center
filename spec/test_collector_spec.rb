TestCollector = TestCenter::Helper::TestCollector
describe TestCenter do
  describe TestCenter::Helper do
    describe TestCollector do
      it 'finds testable from given xctestrun' do
        allow(Plist).to receive(:parse_xml).with('path/to/fake.xctestrun').and_return({ 'AtomicBoyTests' => [] })
        test_collector = TestCollector.new(
          xctestrun: 'path/to/fake.xctestrun'
        )
        expect(test_collector.testables).to eq(['AtomicBoyTests'])
      end

      it 'finds testables from derived xctestrun' do
        allow(Dir).to receive(:glob).with("path/to/fake/derived_data/Build/Products/Professor*.xctestrun").and_return(['path/to/fake/derived_data/Build/Products/Professor_Blahblah.xctestrun'])
        allow(Plist).to receive(:parse_xml).with("path/to/fake/derived_data/Build/Products/Professor_Blahblah.xctestrun").and_return({ 'AtomicBoyTests' => [], 'AtomicBoyUITests' => [] })
        test_collector = TestCollector.new(
          derived_data_path: 'path/to/fake/derived_data',
          scheme: 'Professor'
        )
        expect(test_collector.testables).to eq(['AtomicBoyTests', 'AtomicBoyUITests'])
      end

      it 'calls to testables :only_testing returns those testables' do
        expect(Plist).not_to receive(:parse_xml)
        expect(Fastlane::Actions::TestsFromXctestrunAction).not_to receive(:run)
        test_collector = TestCollector.new(
          xctestrun: 'path/to/fake.xctestrun',
          only_testing: [
            'AtomicBoyTests/AtomicBoyTests/testExample1',
            'AtomicBoyUITests/AtomicBoyUITests/testExample3',
            'AtomicBoyUITests/AtomicBoyUITests/testExample4'
          ]
        )
        result = test_collector.testables
        expect(result).to include('AtomicBoyTests', 'AtomicBoyUITests')
      end

      it 'calls to testables_tests returns Hash of only_testing' do
        expect(Fastlane::Actions::TestsFromXctestrunAction).not_to receive(:run)
        test_collector = TestCollector.new(
          xctestrun: 'path/to/fake.xctestrun',
          only_testing: [
            'AtomicBoyTests/AtomicBoyTests/testExample1',
            'AtomicBoyUITests/AtomicBoyUITests/testExample3',
            'AtomicBoyUITests/AtomicBoyUITests/testExample4'
          ]
        )
        result = test_collector.testables_tests
        expect(result).to include(
          'AtomicBoyTests' => [
            'AtomicBoyTests/AtomicBoyTests/testExample1'
          ],
          'AtomicBoyUITests' => [
            'AtomicBoyUITests/AtomicBoyUITests/testExample3',
            'AtomicBoyUITests/AtomicBoyUITests/testExample4'
          ]
        )
      end

      it 'calls to testables_tests returns Hash of without tests from :skip_testing' do
        allow(File).to receive(:exist?).with('path/to/fake.xctestrun').and_return(true)
        expect(Fastlane::Actions::TestsFromXctestrunAction).to receive(:run)
          .and_return(
            'AtomicBoyTests' => [
              'AtomicBoyTests/AtomicBoyTests/testExample1',
              'AtomicBoyTests/AtomicBoyTests/testExample2',
              'AtomicBoyTests/AtomicBoyTests/testExample3',
              'AtomicBoyTests/AtomicBoyTests/testExample4'
            ],
            'AtomicBoyUITests' => [
              'AtomicBoyUITests/AtomicBoyUITests/testExample1',
              'AtomicBoyUITests/AtomicBoyUITests/testExample2',
              'AtomicBoyUITests/AtomicBoyUITests/testExample3',
              'AtomicBoyUITests/AtomicBoyUITests/testExample4'
            ]
          )
        test_collector = TestCollector.new(
          xctestrun: 'path/to/fake.xctestrun',
          skip_testing: [
            'AtomicBoyTests/AtomicBoyTests/testExample2',
            'AtomicBoyTests/AtomicBoyTests/testExample3',
            'AtomicBoyUITests/AtomicBoyUITests/testExample4'
          ]
        )
        result = test_collector.testables_tests
        expect(result).to include(
          'AtomicBoyTests' => [
            'AtomicBoyTests/AtomicBoyTests/testExample1',
            'AtomicBoyTests/AtomicBoyTests/testExample4'
          ],
          'AtomicBoyUITests' => [
            'AtomicBoyUITests/AtomicBoyUITests/testExample1',
            'AtomicBoyUITests/AtomicBoyUITests/testExample2',
            'AtomicBoyUITests/AtomicBoyUITests/testExample3'
          ]
        )
      end

      it 'multiple testables_tests calls tests_from_xctestrun action once' do
        test_collector = TestCollector.new(
          xctestrun: 'path/to/fake.xctestrun'
        )
        expected_result = {
          'AtomicBoyTests' => [
            'AtomicBoyTests/AtomicBoyTests/testExample1',
            'AtomicBoyTests/AtomicBoyTests/testExample2',
            'AtomicBoyTests/AtomicBoyTests/testExample3',
            'AtomicBoyTests/AtomicBoyTests/testExample4'
          ]
        }
        allow(File).to receive(:exist?).with('path/to/fake.xctestrun').and_return(true)
        expect(Fastlane::Actions::TestsFromXctestrunAction).to receive(:run)
          .and_return(expected_result).once
        result = test_collector.testables_tests
        expect(result).to include(expected_result)
        result = test_collector.testables_tests
        expect(result).to include(expected_result)
      end
    end
  end
end
