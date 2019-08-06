module Fastlane
  module Actions
    class CollateJunitReportsAction < Action

      def self.run(params)
        report_filepaths = params[:reports]
        if report_filepaths.size == 1
          FileUtils.cp(report_filepaths[0], params[:collated_report])
        else
          UI.verbose("collate_junit_reports with #{report_filepaths}")
          reports = report_filepaths.map { |report_filepath| REXML::Document.new(File.new(report_filepath)) }
          # copy any missing testsuites
          target_report = reports.shift
          preprocess_testsuites(target_report)

          reports.each do |report|
            increment_testable_tries(target_report.root, report.root)
            preprocess_testsuites(report)
            UI.verbose("> collating last report file #{report_filepaths.last}")
            report.elements.each('//testsuite') do |testsuite|
              testsuite_name = testsuite.attributes['name']
              target_testsuite = REXML::XPath.first(target_report, "//testsuite[@name='#{testsuite_name}']")
              if target_testsuite
                UI.verbose("  > collating testsuite #{testsuite_name}")
                collate_testsuite(target_testsuite, testsuite)
                UI.verbose("  < collating testsuite #{testsuite_name}")
              else
                testable = REXML::XPath.first(target_report, "//testsuites")
                testable << testsuite
              end
            end
            UI.verbose("< collating last report file #{report_filepaths.last}")
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

      def self.collapse_testcase_multiple_failures_in_testsuite(testsuite)
        testcases_with_failures = REXML::XPath.match(testsuite, 'testcase[failure]')

        while testcases_with_failures.size > 1
          target_testcase = testcases_with_failures.shift

          name = target_testcase.attributes['name']
          classname = target_testcase.attributes['classname']

          failures = REXML::XPath.match(testsuite, "testcase[@name='#{name}'][@classname='#{classname}']/failure")
          next unless failures.size > 1

          failures[1..-1].each do |failure|
            failure_clone = failure.clone
            failure_clone.text = failure.text
            target_testcase << failure_clone

            testsuite.delete_element(failure.parent)
            testcases_with_failures.delete(failure.parent)
          end
        end
      end

      def self.flatten_duplicate_testsuites(report, testsuite)
        testsuite_name = testsuite.attributes['name']
        duplicate_testsuites = REXML::XPath.match(report, "//testsuite[@name='#{testsuite_name}']")
        if duplicate_testsuites.size > 1
          UI.verbose("    > flattening_duplicate_testsuites")
          duplicate_testsuites.drop(1).each do |duplicate_testsuite|
            collate_testsuite(testsuite, duplicate_testsuite)
            duplicate_testsuite.parent.delete_element(duplicate_testsuite)
          end
          UI.verbose("    < flattening_duplicate_testsuites")
        end
        update_testsuite_counts(testsuite)
      end

      def self.preprocess_testsuites(report)
        report.elements.each('//testsuite') do |testsuite|
          flatten_duplicate_testsuites(report, testsuite)
          collapse_testcase_multiple_failures_in_testsuite(testsuite)
        end
      end

      def self.collate_testsuite(target_testsuite, other_testsuite)
        other_testsuite.elements.each('testcase') do |testcase|
          classname = testcase.attributes['classname']
          name = testcase.attributes['name']
          target_testcase = REXML::XPath.first(target_testsuite, "testcase[@name='#{name}' and @classname='#{classname}']")
          # Replace target_testcase with testcase
          if target_testcase
            UI.verbose("      collate_testsuite with testcase #{name}")
            UI.verbose("      replacing \"#{target_testcase}\" with \"#{testcase}\"")
            parent = target_testcase.parent
            increment_testcase_tries(target_testcase, testcase) unless testcase.root == target_testcase.root 
            parent.insert_after(target_testcase, testcase)
            parent.delete_element(target_testcase)
            UI.verbose("")
            UI.verbose("      target_testcase after replacement \"#{parent}\"")
          else
            target_testsuite << testcase
          end
        end
      end

      def self.increment_testable_tries(target_testable, other_testable)
        try_count = target_testable.attributes['retries'] || 1
        other_try_count = other_testable['retries'] || 1

        target_testable.attributes['retries'] = (try_count.to_i + other_try_count.to_i).to_s
      end

      def self.increment_testcase_tries(target_testcase, testcase)
        try_count = target_testcase.attributes['retries']
        testcase.attributes['retries'] = (try_count.to_i + 1).to_s
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
      # :nocov:
      def self.description
        "Combines multiple junit report files into one junit report file"
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

      def self.category
        :testing
      end

      def self.is_supported?(platform)
        %i[ios mac].include?(platform)
      end
      # :nocov:
    end
  end
end
