describe TestCenter::Helper::RetryingScan do
  describe 'report_collator' do

    ReportCollator = TestCenter::Helper::RetryingScan::ReportCollator
    ReportNameHelper = TestCenter::Helper::ReportNameHelper

    it 'collates' do
      reportnamer = ReportNameHelper.new(
        'junit',
        'report.xml'
      )
      collator = ReportCollator.new(
        output_directory: '.',
        reportnamer: reportnamer
      )
      expect(collator).to receive(:collate_json_reports)
      expect(collator).to receive(:collate_html_reports)
      expect(collator).to receive(:collate_junit_reports)
      expect(collator).to receive(:collate_test_result_bundles)
      collator.collate
    end

    it 'collates junit reports correctly' do
      reportnamer = ReportNameHelper.new(
        'junit',
        'report.xml'
      )
      collator = ReportCollator.new(
        output_directory: '.',
        reportnamer: reportnamer
      )
      expect(collator).to receive(:sort_globbed_files).with('./report*.xml').and_return(['report.xml', 'report-1.xml', 'report-2.xml'])
      config = OpenStruct.new
      allow(config).to receive(:_values).and_return(
        {
            reports: ['report.xml', 'report-1.xml', 'report-2.xml'],
            collated_report: 'report.xml'
          }
      )
      expect(collator).to receive(:create_config).and_return(config)
      expect(Fastlane::Actions::CollateJunitReportsAction).to receive(:run) do |c|
        expect(c._values).to eq(
          {
            reports: ['report.xml', 'report-1.xml', 'report-2.xml'],
            collated_report: 'report.xml'
          }
        )
      end
      expect(collator).to receive(:delete_globbed_intermediatefiles).with('./report-[1-9]*.xml')
      collator.collate_junit_reports
    end

    it 'collates html reports correctly' do
      reportnamer = ReportNameHelper.new(
        'html',
        'report.html'
      )
      collator = ReportCollator.new(
        output_directory: '.',
        reportnamer: reportnamer
      )
      expect(collator).to receive(:sort_globbed_files).with('./report*.html').and_return(['report.html', 'report-1.html', 'report-2.html'])
      config = OpenStruct.new
      allow(config).to receive(:_values).and_return(
        {
            reports: ['report.html', 'report-1.html', 'report-2.html'],
            collated_report: 'report.html'
          }
      )
      expect(collator).to receive(:create_config).and_return(config)
      expect(Fastlane::Actions::CollateHtmlReportsAction).to receive(:run) do |c|
        expect(c._values).to eq(
          {
            reports: ['report.html', 'report-1.html', 'report-2.html'],
            collated_report: 'report.html'
          }
        )
      end
      expect(collator).to receive(:delete_globbed_intermediatefiles).with('./report-[1-9]*.html')

      collator.collate_html_reports
    end

    it 'collates json reports correctly' do
      reportnamer = ReportNameHelper.new(
        'json',
        'report.json'
      )
      collator = ReportCollator.new(
        output_directory: '.',
        reportnamer: reportnamer
      )
      expect(collator).to receive(:sort_globbed_files).with('./report*.json').and_return(['report.json', 'report-1.json', 'report-2.json'])
      config = OpenStruct.new
      allow(config).to receive(:_values).and_return(
        {
            reports: ['report.json', 'report-1.json', 'report-2.json'],
            collated_report: 'report.json'
          }
      )
      expect(collator).to receive(:create_config).and_return(config)
      expect(Fastlane::Actions::CollateJsonReportsAction).to receive(:run) do |c|
        expect(c._values).to eq(
          {
            reports: ['report.json', 'report-1.json', 'report-2.json'],
            collated_report: 'report.json'
          }
        )
      end
      expect(collator).to receive(:delete_globbed_intermediatefiles).with('./report-[1-9]*.json')

      collator.collate_json_reports
    end

    it 'collates test_result bundles correctly' do
      reportnamer = ReportNameHelper.new(
        'json',
        'report.json'
      )
      collator = ReportCollator.new(
        output_directory: '.',
        reportnamer: reportnamer,
        scheme: 'HappyHippo',
        result_bundle: true
      )
      expect(collator).to receive(:sort_globbed_files).with('./HappyHippo*.test_result').and_return(['HappyHippo.test_result', 'HappyHippo-1.test_result', 'HappyHippo-2.test_result'])
      config = OpenStruct.new
      allow(config).to receive(:_values).and_return(
        {
            bundles: ['HappyHippo.test_result', 'HappyHippo-1.test_result', 'HappyHippo-2.test_result'],
            collated_bundle: 'HappyHippo.test_result'
          }
      )
      expect(collator).to receive(:create_config).and_return(config)
      expect(Fastlane::Actions::CollateTestResultBundlesAction).to receive(:run) do |c|
        expect(c._values).to eq(
          {
            bundles: ['HappyHippo.test_result', 'HappyHippo-1.test_result', 'HappyHippo-2.test_result'],
            collated_bundle: 'HappyHippo.test_result'
          }
        )
      end
      expect(collator).to receive(:delete_globbed_intermediatefiles).with('./HappyHippo-[1-9]*.test_result')

      collator.collate_test_result_bundles
    end

  end
end
