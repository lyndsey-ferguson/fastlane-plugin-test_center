

describe Fastlane::Actions::TestsFromJunitAction do
  describe 'it handles invalid data' do
    it 'a failure occurs when a non-existent Junit file is specified' do
      fastfile = "lane :test do
        tests_from_junit(
          junit: 'path/to/non_existent_junit_report.xml'
        )
      end"
      expect { Fastlane::FastFile.new.parse(fastfile).runner.execute(:test) }.to(
        raise_error(FastlaneCore::Interface::FastlaneError) do |error|
          expect(error.message).to match("Error: cannot find the junit xml report file 'path/to/non_existent_junit_report.xml'")
        end
      )
    end
  end

  it 'returns all tests in a junit report' do
    fastfile = "lane :test do
      tests_from_junit(
        junit: 'path/to/fake_junit_report.xml'
      )
    end"
    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:exist?).with('path/to/fake_junit_report.xml').and_return(true)
    allow(File).to receive(:open).with('path/to/fake_junit_report.xml').and_yield(File.open('./spec/fixtures/junit.xml'))

    result = Fastlane::FastFile.new.parse(fastfile).runner.execute(:test)
    expect(result[:failed]).to eq(['CoinTossingUITests/testResultIsTails'])
    expect(result[:passing]).to eq(['CoinTossingUITests/testResultIsHeads'])
  end
end
