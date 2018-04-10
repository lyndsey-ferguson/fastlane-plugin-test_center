
html_report_1 = File.open('./spec/fixtures/report.html')
html_report_2 = File.open('./spec/fixtures/report-2.html')
html_report_3 = File.open('./spec/fixtures/report-3.html')

def testidentifiers_from_xmlreport(report)
  testable = REXML::XPath.first(report, "//section[@id='test-suites']")
  testsuites = REXML::XPath.match(testable, "section[contains(@class, 'test-suite')]")
  testidentifiers = []
  testsuites.each do |testsuite|
    testidentifiers += REXML::XPath.match(testsuite, ".//*[contains(@class, 'tests')]//*[contains(@class, 'test')]//*[contains(@class, 'title')]").map do |testcase|
      "#{testsuite.attributes['id']}/#{testcase.text.strip}"
    end
  end
  testidentifiers
end

describe Fastlane::Actions::CollateHtmlReportsAction do
  before(:each) do
    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:open).and_call_original
  end

  describe 'it handles invalid data' do
    it 'a failure occurs when non-existent HTML file is specified' do
      fastfile = "lane :test do
        collate_html_reports(
          reports: ['path/to/non_existent_html_report.html'],
          collated_report: 'path/to/report.html'
        )
      end"
      expect { Fastlane::FastFile.new.parse(fastfile).runner.execute(:test) }.to(
        raise_error(FastlaneCore::Interface::FastlaneError) do |error|
          expect(error.message).to match("Error: HTML report not found: 'path/to/non_existent_html_report.html'")
        end
      )
    end
  end

  describe 'it handles valid data' do
    it 'simply copies a :reports value containing one report' do
      fastfile = "lane :test do
        collate_html_reports(
          reports: ['path/to/fake_html_report.html'],
          collated_report: 'path/to/report.html'
        )
      end"
      allow(File).to receive(:exist?).with('path/to/fake_html_report.html').and_return(true)
      allow(File).to receive(:open).with('path/to/fake_html_report.html').and_yield(File.open('./spec/fixtures/report.html'))
      expect(FileUtils).to receive(:cp).with('path/to/fake_html_report.html', 'path/to/report.html')
      Fastlane::FastFile.new.parse(fastfile).runner.execute(:test)
    end

    it 'merges missing testsuites into one file' do
      fastfile = "lane :test do
        collate_html_reports(
          reports: ['path/to/fake_html_report_1.html', 'path/to/fake_html_report_2.html'],
          collated_report: 'path/to/report.html'
        )
      end"

      allow(File).to receive(:exist?).with('path/to/fake_html_report_1.html').and_return(true)
      allow(File).to receive(:new).with('path/to/fake_html_report_1.html').and_return(html_report_1)
      allow(File).to receive(:exist?).with('path/to/fake_html_report_2.html').and_return(true)
      allow(File).to receive(:new).with('path/to/fake_html_report_2.html').and_return(html_report_2)
      allow(FileUtils).to receive(:mkdir_p)

      report_file = StringIO.new
      expect(File).to receive(:open).with('path/to/report.html', 'w').and_yield(report_file)

      Fastlane::FastFile.new.parse(fastfile).runner.execute(:test)
      report = REXML::Document.new(report_file.string)
      actual_test_identifiers = testidentifiers_from_xmlreport(report)
      expect(actual_test_identifiers).to contain_exactly(
        'AtomicBoyUITests/testExample',
        'AtomicBoyUITests/testExample2',
        'AtomicBoyUITests.SwiftAtomicBoyUITests/testExample'
      )
      failing_testcases = REXML::XPath.match(report, ".//*[contains(@class, 'tests')]//*[contains(@class, 'test') and contains(@class, 'failing')]//*[contains(@class, 'title')]")
      expect(failing_testcases.size).to eq(1)
      failing_testcase = failing_testcases.first
      failing_testclass = REXML::XPath.match(failing_testcase, "ancestor::*/*[contains(@class, 'test-suite')]")[0]
      expect(failing_testclass.attributes['id']).to eq('AtomicBoyUITests')
      expect(failing_testcase.text.strip).to eq('testExample')

      failing_testcase_details = REXML::XPath.match(report, ".//*[contains(@class, 'tests')]//*[contains(@class, 'details') and contains(@class, 'failing')]")
      expect(failing_testcase_details.size).to eq(1)
      failing_testcase_class = failing_testcase_details[0].attributes['class']
      expect(failing_testcase_class.split(' ')).to include('testExample')

      test_count = REXML::XPath.first(report, ".//*[@id='test-count']/span").text.strip
      expect(test_count).to eq('3')
      fail_count = REXML::XPath.first(report, ".//*[@id='fail-count']/span").text.strip
      expect(fail_count).to eq('1')

      failing_testsuites = REXML::XPath.match(report, "//*[contains(@class, 'test-suite') and contains(@class, 'failing')]")
      expect(failing_testsuites.size).to eq(1)
      passing_testsuites = REXML::XPath.match(report, "//*[contains(@class, 'test-suite') and contains(@class, 'passing')]")
      expect(passing_testsuites.size).to eq(1)
    end
  end
end
