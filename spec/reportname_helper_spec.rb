ReportNameHelper = TestCenter::Helper::ReportNameHelper
describe TestCenter do
  describe TestCenter::Helper do
    describe ReportNameHelper do
      it 'provides the correct scan options when given :output_types and :output_files' do
        helper = ReportNameHelper.new('html,junit', 'report.html,report.xml')
        expect(helper.scan_options).to include(
          output_types: 'html,junit',
          output_files: 'report.html,report.xml'
        )
      end
      it 'provides the correct scan options when given :custom_report_file_name' do
        helper = ReportNameHelper.new('junit', 'report.xml')
        expect(helper.scan_options).to include(
          output_types: 'junit',
          output_files: 'report.xml'
        )
      end
      it 'provides the correct scan options when given :output_types, :output_files, and :custom_report_file_name' do
        helper = ReportNameHelper.new('junit', 'report.junit', 'report.xml')
        expect(helper.scan_options).to include(
          output_types: 'junit',
          output_files: 'report.junit'
        )
      end
      it 'provides the correct scan options when given no options' do
        helper = ReportNameHelper.new
        expect(helper.scan_options).to include(
          output_types: 'junit',
          output_files: 'report.junit'
        )
      end
      it 'provides the correct scan options when given no junit option via :output_files' do
        helper = ReportNameHelper.new('html', 'report.html')
        expect(helper.scan_options).to include(
          output_types: 'html,junit',
          output_files: 'report.html,report.xml'
        )
      end
      it 'provides the correct scan options when given :output_types but no filenames' do
        helper = ReportNameHelper.new('html,junit')
        expect(helper.scan_options).to include(
          output_types: 'html,junit',
          output_files: 'report.html,report.junit'
        )
      end
      it 'provides the correct scan options when given no junit option via :custom_report_file_name' do
        helper = ReportNameHelper.new('html', nil, 'report.html')
        expect(helper.scan_options).to include(
          output_types: 'html,junit',
          output_files: 'report.html,report.xml'
        )
      end
      it 'provides the correct scan options when given :output_types with json' do
        helper = ReportNameHelper.new('json', nil, 'report.json')
        expect(helper.scan_options).to include(
          output_types: 'junit',
          output_files: 'report.xml',
          formatter: 'xcpretty-json-formatter'
        )
        helper = ReportNameHelper.new('json')
        expect(helper.scan_options).to include(
          output_types: 'junit',
          output_files: 'report.xml',
          formatter: 'xcpretty-json-formatter'
        )
      end
      it 'raises an exception when given multiple :output_types and only one :custom_report_file_name' do
        expect { ReportNameHelper.new('html,junit', nil, 'report.xml') }.to(
          raise_error(ArgumentError) do |error|
            expect(error.message).to eq('Error: count of :output_types, ["html", "junit"], does not match the output filename(s) ["report.xml"]')
          end
        )
      end
      it 'raises an exception when given more :output_types than :output_files' do
        expect { ReportNameHelper.new('html,junit', 'report.xml') }.to(
          raise_error(ArgumentError) do |error|
            expect(error.message).to eq('Error: count of :output_types, ["html", "junit"], does not match the output filename(s) ["report.xml"]')
          end
        )
      end
      it 'raises an exception when given fewer :output_types than :output_files' do
        expect { ReportNameHelper.new('junit', 'report.xml,report.json-compilation-database') }.to(
          raise_error(ArgumentError) do |error|
            expect(error.message).to eq('Error: count of :output_types, ["junit"], does not match the output filename(s) ["report.xml", "report.json-compilation-database"]')
          end
        )
      end
      it 'provides the base junit report filename when given all options' do
        helper = ReportNameHelper.new('junit', 'report.junit', 'report.xml')
        expect(helper.junit_reportname).to eq('report.junit')

        helper = ReportNameHelper.new('html,junit', 'report.html,report.junit', 'report.xml')
        expect(helper.junit_reportname).to eq('report.junit')
      end

      it 'provides the base junit report filename when given :output_types and :custom_report_file_name' do
        helper = ReportNameHelper.new('junit', nil, 'report.xml')
        expect(helper.junit_reportname).to eq('report.xml')
        helper.increment
        expect(helper.junit_reportname).to eq('report.xml')
      end

      it 'provides the junit file extension' do
        helper = ReportNameHelper.new('junit', 'report.xml')
        expect(helper.junit_filextension).to eq('.xml')

        helper = ReportNameHelper.new('junit,html', 'report.junit,report.html')
        expect(helper.junit_filextension).to eq('.junit')
      end

      it 'increments one junit file name for the first time correctly' do
        helper = ReportNameHelper.new('junit', 'report.xml')
        helper.increment
        expect(helper.scan_options).to include(
          output_types: 'junit',
          output_files: 'report-2.xml'
        )
      end
      it 'increments one junit file name for the second time correctly' do
        helper = ReportNameHelper.new('junit', 'report.xml')
        helper.increment
        helper.increment
        expect(helper.scan_options).to include(
          output_types: 'junit',
          output_files: 'report-3.xml'
        )
      end
      it 'increments multiple file names for the first time correctly' do
        helper = ReportNameHelper.new('junit,html', 'report.xml,report.html')
        helper.increment
        expect(helper.scan_options).to include(
          output_types: 'junit,html',
          output_files: 'report-2.xml,report-2.html'
        )
      end
      it 'increments multiple file names for the the second time correctly' do
        helper = ReportNameHelper.new('junit,html', 'report.xml,report.html')
        helper.increment
        helper.increment
        expect(helper.scan_options).to include(
          output_types: 'junit,html',
          output_files: 'report-3.xml,report-3.html'
        )
      end
      it 'provides the last reportname for each iteration' do
        helper = ReportNameHelper.new('junit,html', 'report.xml,report.html')
        expect(helper.junit_last_reportname).to eq('report.xml')
        helper.increment
        expect(helper.junit_last_reportname).to eq('report-2.xml')
      end

      it 'provides the last reportname for each iteration when specifying json as an output_type' do
        helper = ReportNameHelper.new('junit,json', 'report.xml,report.json')
        expect(helper.json_last_reportname).to eq('report.json')
        helper.increment
        expect(helper.json_last_reportname).to eq('report-2.json')
      end
    end
  end
end
