
junit_report_1 = "<?xml version='1.0' encoding='UTF-8'?>" \
"<testsuites name='AtomicBoyUITests.xctest' tests='2' failures='0'>" \
"  <testsuite name='AtomicBoyTests' tests='2' failures='0'>" \
"    <testcase classname='AtomicBoyTests' name='testExample' time='0.001'/>" \
"    <testcase classname='AtomicBoyTests' name='testPerformanceExample' time='0.307'/>" \
"  </testsuite>" \
"</testsuites>"

junit_report_2 = "<?xml version='1.0' encoding='UTF-8'?>" \
"<testsuites name='AtomicBoyUITests.xctest' tests='3' failures='2'>" \
"  <testsuite name='AtomicBoyUITests' tests='2' failures='1'>" \
"    <testcase classname='AtomicBoyUITests' name='testExample' time='4.397'/>" \
"    <testcase classname='AtomicBoyUITests' name='testExample2'>" \
"      <failure message='((false) is true) failed'>AtomicBoyUITests.m:48</failure>" \
"    </testcase>" \
"    <testcase classname='AtomicBoyUITests' name='testExample2'>" \
"      <failure message='All the grass is not green'>AtomicBoyUITests.m:987</failure>" \
"    </testcase>" \
"    <testcase classname='AtomicBoyUITests' name='testExample2'>" \
"      <failure message='All that glitters is not gold'>AtomicBoyUITests.m:infinity</failure>" \
"    </testcase>" \
"  </testsuite>" \
"</testsuites>"

junit_report_3 = "<?xml version='1.0' encoding='UTF-8'?>" \
"<testsuites name='AtomicBoyUITests.xctest' tests='1' failures='0'>" \
"  <testsuite name='AtomicBoyUITests' tests='1' failures='0'>" \
"    <testcase classname='AtomicBoyUITests' name='testExample2' time='4.397' />" \
"  </testsuite>" \
"</testsuites>"

issue_70_report = File.read('./spec/fixtures/issue_70_report.xml')
issue_70_report_2 = File.read('./spec/fixtures/issue_70_report-2.xml')

issue_43_report = "<?xml version='1.0' encoding='UTF-8'?>" \
"<testsuites name='AtomicBoyUITests.xctest' tests='3' failures='2'>" \
"  <testsuite name='AtomicBoyUITests' tests='2' failures='1'>" \
"    <testcase classname='AtomicBoyUITests' name='testExample' time='4.397'/>" \
"    <testcase classname='AtomicBoyUITests' name='testExample2'>" \
"      <failure message='((false) is true) failed'>AtomicBoyUITests.m:48</failure>" \
"    </testcase>" \
"    <testcase classname='AtomicBoyUITests' name='testExample3'>" \
"      <failure message='All the grass is not green'>AtomicBoyUITests.m:987</failure>" \
"    </testcase>" \
"    <testcase classname='AtomicBoyUITests' name='testExample4'>" \
"      <failure message='All that glitters is not gold'>AtomicBoyUITests.m:infinity</failure>" \
"    </testcase>" \
"  </testsuite>" \
"</testsuites>"

issue_43_report_2 = "<?xml version='1.0' encoding='UTF-8'?>" \
"<testsuites name='AtomicBoyUITests.xctest' tests='3' failures='2'>" \
"  <testsuite name='AtomicBoyUITests' tests='2' failures='1'>" \
"    <testcase classname='AtomicBoyUITests' name='testExample' time='4.397'/>" \
"    <testcase classname='AtomicBoyUITests' name='testExample2'>" \
"      <failure message='((false) is true) failed'>AtomicBoyUITests.m:48</failure>" \
"    </testcase>" \
"    <testcase classname='AtomicBoyUITests' name='testExample3' time='4.397'/>" \
"    <testcase classname='AtomicBoyUITests' name='testExample4'>" \
"      <failure message='All that glitters is not gold'>AtomicBoyUITests.m:infinity</failure>" \
"    </testcase>" \
"  </testsuite>" \
"</testsuites>"

issue_43_report_3 = "<?xml version='1.0' encoding='UTF-8'?>" \
"<testsuites name='AtomicBoyUITests.xctest' tests='3' failures='2'>" \
"  <testsuite name='AtomicBoyUITests' tests='2' failures='1'>" \
"    <testcase classname='AtomicBoyUITests' name='testExample' time='4.397'/>" \
"    <testcase classname='AtomicBoyUITests' name='testExample2'>" \
"      <failure message='((false) is true) failed'>AtomicBoyUITests.m:48</failure>" \
"    </testcase>" \
"    <testcase classname='AtomicBoyUITests' name='testExample4' time='4.397'/>" \
"  </testsuite>" \
"</testsuites>"

describe Fastlane::Actions::CollateJunitReportsAction do
  before(:each) do
    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:open).and_call_original
  end

  describe 'it handles invalid data' do
    it 'a failure occurs when non-existent Junit file is specified' do
      fastfile = "lane :test do
        collate_junit_reports(
          reports: ['path/to/non_existent_junit_report.xml'],
          collated_report: 'path/to/report.xml'
        )
      end"
      expect { Fastlane::FastFile.new.parse(fastfile).runner.execute(:test) }.to(
        raise_error(FastlaneCore::Interface::FastlaneError) do |error|
          expect(error.message).to match("Error: junit report not found: 'path/to/non_existent_junit_report.xml'")
        end
      )
    end
  end

  describe 'it handles valid data' do
    it 'simply copies a :reports value containing one report' do
      fastfile = "lane :test do
        collate_junit_reports(
          reports: ['path/to/fake_junit_report.xml'],
          collated_report: 'path/to/report.xml'
        )
      end"
      allow(File).to receive(:exist?).with('path/to/fake_junit_report.xml').and_return(true)
      allow(File).to receive(:open).with('path/to/fake_junit_report.xml').and_yield(File.open('./spec/fixtures/junit.xml'))
      expect(FileUtils).to receive(:cp).with('path/to/fake_junit_report.xml', 'path/to/report.xml')
      Fastlane::FastFile.new.parse(fastfile).runner.execute(:test)
    end

    it 'merges missing testsuites into one file' do
      fastfile = "lane :test do
        collate_junit_reports(
          reports: ['path/to/fake_junit_report_1.xml', 'path/to/fake_junit_report_2.xml'],
          collated_report: 'path/to/report.xml'
        )
      end"

      allow(File).to receive(:exist?).with('path/to/fake_junit_report_1.xml').and_return(true)
      allow(File).to receive(:new).with('path/to/fake_junit_report_1.xml').and_return(junit_report_1)
      allow(File).to receive(:exist?).with('path/to/fake_junit_report_2.xml').and_return(true)
      allow(File).to receive(:new).with('path/to/fake_junit_report_2.xml').and_return(junit_report_2)
      allow(FileUtils).to receive(:mkdir_p)

      report_file = StringIO.new
      expect(File).to receive(:open).with('path/to/report.xml', 'w').and_yield(report_file)
      Fastlane::FastFile.new.parse(fastfile).runner.execute(:test)
      report = REXML::Document.new(report_file.string)

      testable = REXML::XPath.first(report, "//testsuites")
      testcases = REXML::XPath.match(testable, '*//testcase').map do |testcase|
        "#{testcase.attributes['classname']}/#{testcase.attributes['name']}"
      end
      expect(testcases).to contain_exactly(
        'AtomicBoyTests/testExample',
        'AtomicBoyTests/testPerformanceExample',
        'AtomicBoyUITests/testExample',
        'AtomicBoyUITests/testExample2'
      )
      failing_testcase = REXML::XPath.first(testable, '*//testcase/failure').parent
      expect(failing_testcase.attributes['classname']).to eq('AtomicBoyUITests')
      expect(failing_testcase.attributes['name']).to eq('testExample2')

      expect(testable.attributes['failures']).to eq('1')
      expect(testable.attributes['tests']).to eq('4')
    end

    it 'updates failed tests in subsequent reports' do
      fastfile = "lane :test do
        collate_junit_reports(
          reports: [
            'path/to/fake_junit_report_1.xml',
            'path/to/fake_junit_report_2.xml',
            'path/to/fake_junit_report_3.xml'
          ],
          collated_report: 'path/to/report.xml'
        )
      end"

      allow(File).to receive(:exist?).with('path/to/fake_junit_report_1.xml').and_return(true)
      allow(File).to receive(:new).with('path/to/fake_junit_report_1.xml').and_return(junit_report_1)
      allow(File).to receive(:exist?).with('path/to/fake_junit_report_2.xml').and_return(true)
      allow(File).to receive(:new).with('path/to/fake_junit_report_2.xml').and_return(junit_report_2)
      allow(File).to receive(:exist?).with('path/to/fake_junit_report_3.xml').and_return(true)
      allow(File).to receive(:new).with('path/to/fake_junit_report_3.xml').and_return(junit_report_3)
      allow(FileUtils).to receive(:mkdir_p)

      report_file = StringIO.new
      expect(File).to receive(:open).with('path/to/report.xml', 'w').and_yield(report_file)
      Fastlane::FastFile.new.parse(fastfile).runner.execute(:test)
      report = REXML::Document.new(report_file.string)

      testable = REXML::XPath.first(report, "//testsuites")
      testcases = REXML::XPath.match(testable, '*//testcase').map do |testcase|
        "#{testcase.attributes['classname']}/#{testcase.attributes['name']}"
      end
      expect(testcases).to contain_exactly(
        'AtomicBoyTests/testExample',
        'AtomicBoyTests/testPerformanceExample',
        'AtomicBoyUITests/testExample',
        'AtomicBoyUITests/testExample2'
      )
      expect(REXML::XPath.first(testable, '*//testcase/failure')).to be_nil
      expect(testable.attributes['failures']).to eq('0')
      expect(testable.attributes['tests']).to eq('4')
    end
  end

  it 'it collates issue 70 reports' do
    fastfile = "lane :test do
        collate_junit_reports(
          reports: ['path/to/fake_junit_report_1.xml', 'path/to/fake_junit_report_2.xml'],
          collated_report: 'path/to/report.xml'
        )
      end"

    allow(File).to receive(:exist?).with('path/to/fake_junit_report_1.xml').and_return(true)
    allow(File).to receive(:new).with('path/to/fake_junit_report_1.xml').and_return(issue_70_report)
    allow(File).to receive(:exist?).with('path/to/fake_junit_report_2.xml').and_return(true)
    allow(File).to receive(:new).with('path/to/fake_junit_report_2.xml').and_return(issue_70_report_2)
    allow(FileUtils).to receive(:mkdir_p)

    report_file = StringIO.new
    expect(File).to receive(:open).with('path/to/report.xml', 'w').and_yield(report_file)
    Fastlane::FastFile.new.parse(fastfile).runner.execute(:test)
    report = REXML::Document.new(report_file.string)

    testable = REXML::XPath.first(report, "//testsuites")
    expect(testable.attributes['failures']).to eq('0')
    expect(testable.attributes['tests']).to eq('173')
  end

  it 'updates the try counts' do
    fastfile = "lane :test do
        collate_junit_reports(
          reports: [
            'path/to/fake_junit_report_1.xml',
            'path/to/fake_junit_report_2.xml',
            'path/to/fake_junit_report_3.xml'
          ],
          collated_report: 'path/to/report.xml'
        )
      end"

    allow(File).to receive(:exist?).with('path/to/fake_junit_report_1.xml').and_return(true)
    allow(File).to receive(:new).with('path/to/fake_junit_report_1.xml').and_return(issue_43_report)
    allow(File).to receive(:exist?).with('path/to/fake_junit_report_2.xml').and_return(true)
    allow(File).to receive(:new).with('path/to/fake_junit_report_2.xml').and_return(issue_43_report_2)
    allow(File).to receive(:exist?).with('path/to/fake_junit_report_3.xml').and_return(true)
    allow(File).to receive(:new).with('path/to/fake_junit_report_3.xml').and_return(issue_43_report_3)
    allow(FileUtils).to receive(:mkdir_p)

    report_file = StringIO.new
    expect(File).to receive(:open).with('path/to/report.xml', 'w').and_yield(report_file)
    Fastlane::FastFile.new.parse(fastfile).runner.execute(:test)
    report = REXML::Document.new(report_file.string)

    testExample2 = REXML::XPath.first(report, "//testcase[@classname='AtomicBoyUITests'][@name='testExample2']")
    expect(testExample2.attributes['retries']).to eq('2')
    testExample3 = REXML::XPath.first(report, "//testcase[@classname='AtomicBoyUITests'][@name='testExample3']")
    expect(testExample3.attributes['retries']).to eq('1')
    testExample4 = REXML::XPath.first(report, "//testcase[@classname='AtomicBoyUITests'][@name='testExample4']")
    expect(testExample4.attributes['retries']).to eq('2')

    expect(report.root.attributes['retries']).to eq('3')
  end
end
