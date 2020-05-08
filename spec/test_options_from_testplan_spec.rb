module Fastlane::Actions
  describe 'TestOptionsFromTestplanAction' do
    describe '.available_options' do
      it 'raises an error if the testplan does not exist' do
        fastfile = "lane :test do
          test_options_from_testplan(
            testplan: 'path/to/non-existent.xctestplan'
          )
        end"

        expect { Fastlane::FastFile.new.parse(fastfile).runner.execute(:test) }.to(
          raise_error(FastlaneCore::Interface::FastlaneError) do |error|
            expect(error.message).to match(%r{Error: Test Plan does not exist at path 'path/to/non-existent.xctestplan'})
          end
        )
      end
    end

    describe '#run' do
      it 'returns the correct code_coverage values' do
        fastfile = "lane :test do
          test_options_from_testplan(
            testplan: '../spec/fixtures/code-coverage.xctestplan'
          )
        end"
        result = Fastlane::FastFile.new.parse(fastfile).runner.execute(:test)
        expect(result[:code_coverage]).to eq(true)

        fastfile = "lane :test do
          test_options_from_testplan(
            testplan: '../spec/fixtures/code-coverage-no.xctestplan'
          )
        end"
        result = Fastlane::FastFile.new.parse(fastfile).runner.execute(:test)
        expect(result[:code_coverage]).to eq(false)
      end
      it 'returns the correct only_testing values' do
        fastfile = "lane :test do
          test_options_from_testplan(
            testplan: '../spec/fixtures/code-coverage-no.xctestplan'
          )
        end"
        result = Fastlane::FastFile.new.parse(fastfile).runner.execute(:test)
        expect(result[:only_testing]).to contain_exactly(
          "AtomicBoyTests/AtomicBoyTests/testExample",
          "AtomicBoyTests/AtomicBoyTests/testPerformanceExample",
          "AtomicBoyUITests/AtomicBoyUITests/testExample",
          "AtomicBoyUITests/AtomicBoyUITests/testExample2",
          "AtomicBoyUITests/AtomicBoyUITests/testExample3"
        )
      end
    end
  end
end

