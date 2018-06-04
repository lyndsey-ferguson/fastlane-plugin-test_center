module Fastlane
  module Actions
    class CollateJunitReportsAction < Action
      def self.run(params)
        report_filepaths = params[:reports]
        if report_filepaths.size == 1
          FileUtils.cp(report_filepaths[0], params[:collated_report])
        else
          reports = report_filepaths.map { |report_filepath| REXML::Document.new(File.new(report_filepath)) }

          # copy any missing testsuites
          target_report = reports.shift
          reports.each do |report|
            report.elements.each('//testsuite') do |testsuite|
              testsuite_name = testsuite.attributes['name']

              target_testsuite = REXML::XPath.first(target_report, "//testsuite[@name='#{testsuite_name}']")
              if target_testsuite
                testsuite.elements.each('testcase') do |testcase|
                  classname = testcase.attributes['classname']
                  name = testcase.attributes['name']
                  target_testcase = REXML::XPath.first(target_testsuite, "testcase[@name='#{name}' and @classname='#{classname}']")
                  # Replace target_testcase with testcase
                  if target_testcase
                    target_testcase.parent.insert_after(target_testcase, testcase)
                    target_testcase.parent.delete_element(target_testcase)
                  else
                    target_testsuite << testcase
                  end
                end
              else
                testable = REXML::XPath.first(target_report, "//testsuites")
                testable << testsuite
              end
            end
          end
          target_report.elements.each('//testsuite') do |testsuite|
            update_testsuite_counts(testsuite)
          end
          testable = REXML::XPath.first(target_report, 'testsuites')
          update_testable_counts(testable)

          FileUtils.mkdir_p(File.dirname(params[:collated_report]))
          File.open(params[:collated_report], 'w') do |f|
            target_report.write(f, 2)
          end
        end
      end

      def self.update_testable_counts(testable)
        testsuites = REXML::XPath.match(testable, 'testsuite')
        test_count = 0
        failure_count = 0
        testsuites.each do |testsuite|
          test_count += testsuite.attributes['tests'].to_i
          failure_count += testsuite.attributes['failures'].to_i
        end
        testable.attributes['tests'] = test_count.to_s
        testable.attributes['failures'] = failure_count.to_s
      end

      def self.update_testsuite_counts(testsuite)
        testcases = REXML::XPath.match(testsuite, 'testcase')
        testsuite.attributes['tests'] = testcases.size.to_s
        failure_count = testcases.reduce(0) do |count, testcase|
          if REXML::XPath.first(testcase, 'failure')
            count += 1
          end
          count
        end
        testsuite.attributes['failures'] = failure_count.to_s
      end

      def self.attribute_sum_string(node1, node2, attribute)
        value1 = node1.attributes[attribute].to_i
        value2 = node2.attributes[attribute].to_i
        (value1 + value2).to_s
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Combines and combines tests from multiple junit report files"
      end

      def self.details
        "The first junit report is used as the base report. Testcases " \
        "from other reports are added if they do not already exist, or " \
        "if the testcases already exist, they are replaced." \
        "" \
        "This is done because it is assumed that fragile tests, when " \
        "re-run will often succeed due to less interference from other " \
        "tests and the subsequent junit reports will have more passed tests." \
        "" \
        "Inspired by Derek Yang's fastlane-plugin-merge_junit_report"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :reports,
            env_name: 'COLLATE_JUNIT_REPORTS_REPORTS',
            description: 'An array of junit reports to collate. The first report is used as the base into which other reports are merged in',
            optional: false,
            type: Array,
            verify_block: proc do |reports|
              UI.user_error!('No junit report files found') if reports.empty?
              reports.each do |report|
                UI.user_error!("Error: junit report not found: '#{report}'") unless File.exist?(report)
              end
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :collated_report,
            env_name: 'COLLATE_JUNIT_REPORTS_COLLATED_REPORT',
            description: 'The final junit report file where all testcases will be merged into',
            optional: true,
            default_value: 'result.xml',
            type: String
          )
        ]
      end

      def self.example_code
        [
          "
          UI.important(
            'example: ' \\
            'collate the xml reports to a temporary file \"result.xml\"'
          )
          reports = Dir['../spec/fixtures/*.xml'].map { |relpath| File.absolute_path(relpath) }
          collate_junit_reports(
            reports: reports,
            collated_report: File.join(Dir.mktmpdir, 'result.xml')
          )
          "
        ]
      end

      def self.authors
        ["lyndsey-ferguson/@lyndseydf"]
      end

      def self.is_supported?(platform)
        platform == :ios
      end
    end
  end
end
