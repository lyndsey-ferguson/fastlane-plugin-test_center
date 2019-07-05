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
            report.elements.each("//section[contains(@class, 'test-suite')]") do |testsuite|
              collate_testsuite(testsuite_from_report(target_report, testsuite), testsuite)
            end
          end
          update_testsuites_status(target_report)
          update_test_counts(target_report)

          FileUtils.mkdir_p(File.dirname(params[:collated_report]))

          File.open(params[:collated_report], 'w') do |f|
            target_report.write(f, 2)
          end
        end
      end

      def self.opened_reports(report_filepaths)
        report_filepaths.map do |report_filepath|
          report = nil
          repair_attempted = false
          begin
            report = REXML::Document.new(File.new(report_filepath))
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
            m = %r{(<section class="test-detail[^"]*">)(.*(<|>).*)(</section>)}.match(line)
            if m
              test_details = m[2]
              test_details.gsub!('<', '&lt;')
              test_details.gsub!('>', '&gt;')
              line = m[1] + test_details + m[4]
            end
            file.puts line
          end
        end
      end

      def self.testsuite_from_report(report, testsuite)
        testsuite_name = testsuite.attributes['id']
        REXML::XPath.first(report, "//section[contains(@class, 'test-suite') and @id='#{testsuite_name}']")
      end

      def self.testcases_from_testsuite(testsuite)
        REXML::XPath.match(testsuite, ".//*[contains(@class, 'tests')]//*[contains(@class, 'test')]//*[contains(@class, 'title')]")
      end

      def self.testcase_from_testsuite(testsuite, testcase_name)
        REXML::XPath.first(testsuite, "*[contains(@class, 'test')]//*[text()='#{testcase_name}']/../..")
      end

      def self.collate_testsuite(target_testsuite, testsuite)
        if target_testsuite
          testcases = testcases_from_testsuite(testsuite)
          testcases.each do |testcase|
            testresult = testcase.parent.parent
            target_testresult = testcase_from_testsuite(target_testsuite, testcase.text)
            collate_testresults(target_testsuite, target_testresult, testresult)
          end
        else
          testable = testsuite.parent
          testable << testsuite
        end
      end

      def self.collate_testresults(target_testsuite, target_testresult, testresult)
        if target_testresult
          collate_testresult_details(target_testresult, testresult)
          target_testresult.parent.replace_child(target_testresult, testresult)
        else
          target_testsuite << testresult
        end
      end

      def self.collate_testresult_details(target_testresult, testresult)
        target_testdetails = details_for_testresult(target_testresult)
        testdetails = details_for_testresult(testresult)

        if target_testdetails
          if testdetails
            target_testresult.parent.replace_child(target_testdetails, testdetails)
          else
            target_testresult.parent.delete_element(target_testdetails)
          end
        end
      end

      def self.update_testsuites_status(report)
        report.elements.each("//section[contains(@class, 'test-suite')]") do |testsuite|
          failing_tests_xpath = "./*[contains(@class, 'tests')]//*[" \
                "contains(@class, 'failing')]"

          class_attributes = testsuite.attributes['class']
          test_failures = REXML::XPath.match(testsuite, failing_tests_xpath)
          test_status = test_failures.size.zero? ? 'passing' : 'failing'

          testsuite.attributes['class'] = class_attributes.sub('failing', test_status)
        end
      end

      def self.update_test_counts(report)
        tests_xpath = "//*[contains(@class, 'tests')]//*[contains(@class, 'test')]//*[contains(@class, 'title')]"
        tests = REXML::XPath.match(report, tests_xpath)

        failing_tests_xpath = "//*[contains(@class, 'tests')]//*[" \
                "contains(@class, 'details') and " \
                "contains(@class, 'failing')]"

        test_failures = REXML::XPath.match(report, failing_tests_xpath)
        test_count = REXML::XPath.first(report, ".//*[@id='test-count']/span")
        if test_count
          test_count.text = tests.size
        end
        fail_count = REXML::XPath.first(report, ".//*[@id='fail-count']/span")
        if fail_count
          fail_count.text = test_failures.size
        end
      end

      def self.details_for_testresult(testresult)
        testcase = REXML::XPath.first(testresult, ".//*[contains(@class, 'title')]")

        xpath = "../*[" \
                "contains(@class, 'details') and " \
                "contains(@class, 'failing') and " \
                "contains(@class, '#{testcase.text}')]"

        REXML::XPath.first(testresult, xpath)
      end

      #####################################################
      # @!group Documentation
      #####################################################

      # :nocov:
      def self.description
        "Combines multiple html report files into one html report file"
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
