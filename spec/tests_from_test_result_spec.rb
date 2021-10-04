describe Fastlane::Actions::TestsFromTestResultAction do
  describe '.available_options' do
    it 'handles a non-existent test_result bundle' do
      fastfile = "lane :test do
        tests_from_test_result(
          test_result: 'path/to/non-existent.test_result'
        )
      end"

      expect { Fastlane::FastFile.new.parse(fastfile).runner.execute(:test) }.to(
        raise_error(FastlaneCore::Interface::FastlaneError) do |error|
          expect(error.message).to match("Error: cannot find the test_result bundle at 'path/to/non-existent.test_result'")
        end
      )
    end

    it 'handles the incorrect type of bundle' do
      fastfile = "lane :test do
        tests_from_test_result(
          test_result: 'path/to/non-existent.xcproject'
        )
      end"

      allow(Dir).to receive(:exist?).and_call_original
      allow(Dir).to receive(:exist?).with("path/to/non-existent.xcproject").and_return(true)

      expect { Fastlane::FastFile.new.parse(fastfile).runner.execute(:test) }.to(
        raise_error(FastlaneCore::Interface::FastlaneError) do |error|
          expect(error.message).to match("Error: cannot parse files that are not in the test_result format")
        end
      )
    end
  end

  describe '.run' do
    it 'returns all tests in a test_result bundle' do
      fastfile = "lane :test do
        tests_from_test_result(
          test_result: '../spec/fixtures/Atomic Boy.test_result'
        )
      end"

      result = Fastlane::FastFile.new.parse(fastfile).runner.execute(:test)
      expect(result[:failed]).to be_empty
      expect(result[:passing]).to contain_exactly(
        "AtomicBoyUITests/testExample",
        "AtomicBoyUITests/testExample2",
        "SwiftAtomicBoyUITests/testExample"
      )
    end
  end
end

