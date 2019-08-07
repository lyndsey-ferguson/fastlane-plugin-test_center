module TestCenter::Helper::MultiScanManager
  describe 'ReportCollator' do
    it 'collates' do
      reportnamer = ReportNameHelper.new(
        'junit',
        'report.xml'
      )
      collator = ReportCollator.new(
        source_reports_directory_glob: '.',
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
        source_reports_directory_glob: '.',
        output_directory: '.',
        reportnamer: reportnamer
      )
      expect(collator).to receive(:sort_globbed_files)
        .with('./report*.xml').and_return(
          [
            'report.xml',
            'report-1.xml',
            'report-2.xml'
          ].map { |f| File.absolute_path(f) }
        )
      config = OpenStruct.new
      allow(config).to receive(:_values).and_return(
        {
            reports: ['report.xml', 'report-1.xml', 'report-2.xml'].map { |f| File.absolute_path(f) },
            collated_report: 'report.xml'
          }
      )
      expect(collator).to receive(:create_config).and_return(config)
      expect(Fastlane::Actions::CollateJunitReportsAction).to receive(:run) do |c|
        expect(c._values).to eq(
          {
            reports: ['report.xml', 'report-1.xml', 'report-2.xml'].map { |f| File.absolute_path(f) },
            collated_report: 'report.xml'
          }
        )
      end
      expect(FileUtils).to receive(:rm_rf).with(
        [
          'report-1.xml', 
          'report-2.xml'
        ].map { |f| File.absolute_path(f) }
      )
      collator.collate_junit_reports
    end

    it 'collates html reports correctly' do
      reportnamer = ReportNameHelper.new(
        'html',
        'report.html'
      )
      collator = ReportCollator.new(
        source_reports_directory_glob: '.',
        output_directory: '.',
        reportnamer: reportnamer
      )
      expect(collator).to receive(:sort_globbed_files)
        .with('./report*.html')
        .and_return(
          ['report.html', 'report-1.html', 'report-2.html'].map { |f| File.absolute_path(f) }
        )

      config = OpenStruct.new
      allow(config).to receive(:_values).and_return(
        {
            reports: ['report.html', 'report-1.html', 'report-2.html'].map { |f| File.absolute_path(f) },
            collated_report: 'report.html'
          }
      )
      expect(collator).to receive(:create_config).and_return(config)
      expect(Fastlane::Actions::CollateHtmlReportsAction).to receive(:run) do |c|
        expect(c._values).to eq(
          {
            reports: ['report.html', 'report-1.html', 'report-2.html'].map { |f| File.absolute_path(f) },
            collated_report: 'report.html'
          }
        )
      end
      expect(FileUtils).to receive(:rm_rf).with(
        [
          'report-1.html', 
          'report-2.html'
        ].map { |f| File.absolute_path(f) }
      )
      collator.collate_html_reports
    end

    it 'collates json reports correctly' do
      reportnamer = ReportNameHelper.new(
        'json',
        'report.json'
      )
      collator = ReportCollator.new(
        source_reports_directory_glob: '.',
        output_directory: '.',
        reportnamer: reportnamer
      )
      expect(collator).to receive(:sort_globbed_files)
        .with('./report*.json')
        .and_return(
          ['report.json', 'report-1.json', 'report-2.json'].map { |f| File.absolute_path(f) }
        )

      config = OpenStruct.new
      allow(config).to receive(:_values).and_return(
        {
            reports: ['report.json', 'report-1.json', 'report-2.json'].map { |f| File.absolute_path(f) },
            collated_report: 'report.json'
          }
      )
      expect(collator).to receive(:create_config).and_return(config)
      expect(Fastlane::Actions::CollateJsonReportsAction).to receive(:run) do |c|
        expect(c._values).to eq(
          {
            reports: ['report.json', 'report-1.json', 'report-2.json'].map { |f| File.absolute_path(f) },
            collated_report: 'report.json'
          }
        )
      end
      expect(FileUtils).to receive(:rm_rf).with(
        [
          'report-1.json', 
          'report-2.json'
        ].map { |f| File.absolute_path(f) }
      )
      
      collator.collate_json_reports
    end

    it 'collates test_result bundles correctly' do
      reportnamer = ReportNameHelper.new(
        'json',
        'report.json'
      )
      collator = ReportCollator.new(
        source_reports_directory_glob: '.',
        output_directory: '.',
        reportnamer: reportnamer,
        scheme: 'HappyHippo',
        result_bundle: true
      )
      expect(collator).to receive(:sort_globbed_files)
        .with('./HappyHippo*.test_result')
        .and_return(
          [
            'HappyHippo.test_result',
            'HappyHippo-1.test_result',
            'HappyHippo-2.test_result'
          ].map { |f| File.absolute_path(f) }
        )
      config = OpenStruct.new
      allow(config).to receive(:_values).and_return(
        {
            bundles: ['HappyHippo.test_result', 'HappyHippo-1.test_result', 'HappyHippo-2.test_result'].map { |f| File.absolute_path(f) },
            collated_bundle: 'HappyHippo.test_result'
          }
      )
      expect(collator).to receive(:create_config).and_return(config)
      expect(Fastlane::Actions::CollateTestResultBundlesAction).to receive(:run) do |c|
        expect(c._values).to eq(
          {
            bundles: ['HappyHippo.test_result', 'HappyHippo-1.test_result', 'HappyHippo-2.test_result'].map { |f| File.absolute_path(f) },
            collated_bundle: 'HappyHippo.test_result'
          }
        )
      end
      expect(FileUtils).to receive(:rm_rf).with(
        [ 'HappyHippo-1.test_result', 'HappyHippo-2.test_result' ].map { |f| File.absolute_path(f) }
      )
      collator.collate_test_result_bundles
    end

    it '#sort_globbed_files' do
      unsorted_files = {
        '/path/to/file1.txt' => '2017-12-28 00:10:14 -0800',
        '/path/to/file2.txt' => '2017-12-27 20:10:14 -0800',
        '/path/to/file3.txt' => '2017-12-27 22:10:14 -0800',
        '/path/to/file4.txt' => '2017-12-28 01:10:14 -0800',
        '/path/to/file5.txt' => '2017-12-28 04:10:14 -0800',
        '/path/to/file6.txt' => '2017-12-28 03:10:14 -0800',
        '/path/to/file7.txt' => '2017-12-28 02:10:14 -0800',
        '/path/to/file8.txt' => '2017-12-27 23:10:14 -0800',
        '/path/to/file9.txt' => '2017-12-27 21:10:14 -0800'
      }
      allow(Dir).to receive(:glob).and_return(unsorted_files.keys)
      allow(File).to receive(:mtime) do |f|
        unsorted_files[f]
      end
      report_collator = ReportCollator.new({})
      sorted_files = report_collator.sort_globbed_files('./path/to/*.txt')
      expect(sorted_files).to eq(
        [
          "/path/to/file2.txt",
          "/path/to/file9.txt",
          "/path/to/file3.txt",
          "/path/to/file8.txt",
          "/path/to/file1.txt",
          "/path/to/file4.txt",
          "/path/to/file7.txt",
          "/path/to/file6.txt",
          "/path/to/file5.txt"
        ]
      )
    end

    it '#delete_globbed_intermediatefiles' do
      report_collator = ReportCollator.new({})
      intermediate_files = [
        "/path/to/file2.txt",
        "/path/to/file9.txt",
        "/path/to/file3.txt",
        "/path/to/file8.txt",
        "/path/to/file1.txt",
        "/path/to/file4.txt",
        "/path/to/file7.txt",
        "/path/to/file6.txt",
        "/path/to/file5.txt"
      ]
      allow(Dir).to receive(:glob).and_return(intermediate_files)

      expect(FileUtils).to receive(:rm_f).with(intermediate_files)
      report_collator.delete_globbed_intermediatefiles('./path/to/some*.txt')
    end
  end
end
