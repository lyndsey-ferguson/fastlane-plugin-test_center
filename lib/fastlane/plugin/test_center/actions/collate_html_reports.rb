module Fastlane
  module Actions
    class CollateHtmlReportsAction < Action
      def self.run(params)
        report_filepaths = params[:reports]
        if report_filepaths.size == 1
          FileUtils.cp(report_filepaths[0], params[:collated_report])
        else
          reports = opened_reports(report_filepaths)

          # copy any missing testsuites
          target_report = reports.shift
          reports.each do |report|
            target_report.collate_report(report)
          end

          FileUtils.mkdir_p(File.dirname(params[:collated_report]))
          target_report.save_report(params[:collated_report])
        end
      end

      def self.opened_reports(report_filepaths)
        report_filepaths.map do |report_filepath|
          report = nil
          repair_attempted = false
          begin
            report = ::TestCenter::Helper::HtmlTestReport::Report.new(REXML::Document.new(File.new(report_filepath)))
          rescue REXML::ParseException => e
            if repair_attempted
              UI.important("'#{report_filepath}' is malformed and :collate_html_reports cannot repair it")
              raise e
            else
              UI.important("'#{report_filepath}' is malformed. Attempting to repair it")
              repair_attempted = true
              repair_malformed_html(report_filepath)
              retry
            end
          end
          report
        end
      end

      def self.repair_malformed_html(html_report_filepath)
        html_file_contents = File.read(html_report_filepath)
        File.open(html_report_filepath, 'w') do |file|
          html_file_contents.each_line do |line|
            m = %r{(<section class="test-detail[^"]*">)(.*(<|>|&(?!amp;)).*)(</section>)}.match(line)
            if m
              test_details = m[2]
              test_details.gsub!(/&(?!amp;)/, '&amp;')
              test_details.gsub!('<', '&lt;')
              test_details.gsub!('>', '&gt;')
              line = m[1] + test_details + m[4]
            end
            file.puts line
          end
        end
      end

      #####################################################
      # @!group Documentation
      #####################################################

      # :nocov:
      def self.description
        "🔶 Combines multiple html report files into one html report file"
      end

      def self.details
        "The first HTML report is used as the base report. Testcases " \
        "from other reports are added if they do not already exist, or " \
        "if the testcases already exist, they are replaced." \
        "" \
        "This is done because it is assumed that fragile tests, when " \
        "re-run will often succeed due to less interference from other " \
        "tests and the subsequent HTML reports will have more passed tests." \
        ""
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :reports,
            env_name: 'COLLATE_HTML_REPORTS_REPORTS',
            description: 'An array of HTML reports to collate. The first report is used as the base into which other reports are merged in',
            optional: false,
            type: Array,
            verify_block: proc do |reports|
              UI.user_error!('No HTML report files found') if reports.empty?
              reports.each do |report|
                UI.user_error!("Error: HTML report not found: '#{report}'") unless File.exist?(report)
              end
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :collated_report,
            env_name: 'COLLATE_HTML_REPORTS_COLLATED_REPORT',
            description: 'The final HTML report file where all testcases will be merged into',
            optional: true,
            default_value: 'result.html',
            type: String
          )
        ]
      end

      def self.example_code
        [
          "
          UI.important(
            'example: ' \\
            'collate the html reports to a temporary file \"result.html\"'
          )
          reports = Dir['../spec/fixtures/*.html'].map { |relpath| File.absolute_path(relpath) }
          collate_html_reports(
            reports: reports,
            collated_report: File.join(Dir.mktmpdir, 'result.html')
          )
          "
        ]
      end

      def self.authors
        ["lyndsey-ferguson/@lyndseydf"]
      end

      def self.is_supported?(platform)
        %i[ios mac].include?(platform)
      end

      def self.category
        :testing
      end
      # :nocov:
    end
  end
end
