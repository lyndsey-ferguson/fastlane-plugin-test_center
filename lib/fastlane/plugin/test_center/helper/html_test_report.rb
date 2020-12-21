module TestCenter
  module Helper
    module HtmlTestReport

      def self.verbose(message)
        return if ENV.fetch('COLLATE_HTML_REPORTS_VERBOSITY', 1).to_i.zero?

        FastlaneCore::UI.verbose(message)
      end

      def self.error(message)
        return if ENV.fetch('COLLATE_HTML_REPORTS_VERBOSITY', 1).to_i.zero?

        FastlaneCore::UI.error(message)
      end

      class Report
        require 'rexml/formatters/transitive'

        attr_reader :root
        def initialize(html_file)
          @root = html_file.root
        end

        def testsuites
          testsuite_elements = REXML::XPath.match(@root, "//section[contains(@class, 'test-suite')]")
          testsuite_elements.map do |testsuite_element|
            TestSuite.new(testsuite_element)
          end
        end

        def add_testsuite(testsuite)
          testsuites_element = REXML::XPath.first(@root, ".//*[@id='test-suites']")
          testsuites_element.push(testsuite.root)
        end

        def collate_report(report)
          testsuites.each(&:remove_duplicate_testcases)
          report.testsuites.each(&:remove_duplicate_testcases)
          HtmlTestReport.verbose("TestCenter::Helper::HtmlTestReport::Report.collate_report to report:\n\t#{@root}")
          report.testsuites.each do |given_testsuite|
            existing_testsuite = testsuite_with_title(given_testsuite.title)
            if existing_testsuite.nil?
              HtmlTestReport.verbose("\tadding testsuite\n\t\t#{given_testsuite}")
              add_testsuite(given_testsuite)
            else
              HtmlTestReport.verbose("\tcollating testsuite\n\t\t#{given_testsuite.root}")
              existing_testsuite.collate_testsuite(given_testsuite)
              HtmlTestReport.verbose("\tafter collation exiting testsuite\n\t\t#{existing_testsuite.root}")
            end
          end
          update_test_count
          update_fail_count
        end

        def testsuite_with_title(title)
          testsuite_element = REXML::XPath.first(@root, ".//*[contains(@id, 'test-suites')]//*[@id='#{title}' and contains(concat(' ', @class, ' '), ' test-suite ')]")
          TestSuite.new(testsuite_element) unless testsuite_element.nil?
        end

        def test_count
          REXML::XPath.first(@root, ".//*[@id = 'counters']//*[@id='test-count']/*[@class = 'number']/text()").to_s.to_i
        end
        
        def set_test_count(test_count)
          test_count_element = REXML::XPath.first(@root, ".//*[@id = 'counters']//*[@id='test-count']/*[@class = 'number']/text()")
          test_count_element.value = test_count.to_s
        end
        
        def update_test_count
          testcase_elements = REXML::XPath.match(@root, "//*[contains(@class, 'tests')]//*[contains(concat(' ', @class, ' '), ' test ')]").uniq
          set_test_count(testcase_elements.size)
        end

        def fail_count
          fail_count_element = REXML::XPath.first(@root, ".//*[@id = 'counters']//*[@id='fail-count']/*[@class = 'number']/text()")
          return fail_count_element.to_s.to_i if fail_count_element
          return 0
        end

        def set_fail_count(fail_count)
          counters_element = REXML::XPath.first(@root, ".//*[@id = 'counters']")
          fail_count_number_element = REXML::XPath.first(counters_element, ".//*[@id='fail-count']/*[@class = 'number']/text()")
          if fail_count_number_element
            fail_count_number_element.value = fail_count.to_s
          else
            test_count_element = REXML::XPath.first(counters_element, ".//*[@id='test-count']")
            fail_count_element = test_count_element.clone
            fail_count_element.add_attribute('id', 'fail-count')

            test_count_element.each_element do |element|
              fail_count_element.add_element(element.clone)
            end
            REXML::XPath.first(fail_count_element, ".//*[@class = 'number']").text = fail_count
            counters_element.add_element(fail_count_element)
          end
        end

        def update_fail_count
          xpath_class_attributes = [
            "contains(concat(' ', @class, ' '), ' test ')",
            "contains(concat(' ', @class, ' '), ' failing ')"
          ].join(' and ')

          failing_testcase_elements = REXML::XPath.match(@root, ".//*[#{xpath_class_attributes}]")
          set_fail_count(failing_testcase_elements.size)
        end

        def add_test_center_footer
          test_center_footer = REXML::XPath.first(@root, ".//footer[@id = 'test-center-footer']")
          return if test_center_footer

          test_center_anchor = REXML::Element.new('a')
          test_center_anchor.text = 'collate_html_reports'
          test_center_anchor.add_attribute('href', 'https://github.com/lyndsey-ferguson/fastlane-plugin-test_center#collate_html_reports')

          test_center_footer = REXML::Element.new('footer')
          test_center_footer.add_attribute('id', 'test-center-footer')
          test_center_footer.text = 'Collated by the '
          test_center_footer.add_element(test_center_anchor)
          test_center_footer.add_text(' action from the test_center fastlane plugin')

          body_element = REXML::XPath.first(@root, "//body")
          body_element.elements.add(test_center_footer)
        end

        def save_report(report_path)
          add_test_center_footer

          output = ''
          formatter = REXML::Formatters::Transitive.new
          formatter.write(@root, output)

          File.open(report_path, 'w') do |f|
            f.puts output
          end
        end
      end

      class TestSuite
        attr_reader :root

        def initialize(testsuite_element)
          @root = testsuite_element
        end

        def title
          @root.attribute('id').value
        end

        def testcases
          testcase_elements = REXML::XPath.match(@root, ".//*[contains(@class, 'tests')]//*[contains(concat(' ', @class, ' '), ' test ')]")
          testcase_elements.map do |testcase_element|
            TestCase.new(testcase_element)
          end
        end

        def testcase_with_title(title)
          found_title_element = REXML::XPath.match(@root, ".//*[contains(@class, 'tests')]//*[contains(concat(' ', @class, ' '), ' test ')]//*[@class='title']").find { |n| n.text.to_s.strip == title  }
          if found_title_element
            testcase_element = found_title_element.parent.parent
            TestCase.new(testcase_element) unless testcase_element.nil?
          end
        end

        def passing?
          @root.attribute('class').value.include?('passing')
        end

        def set_passing(status)
          desired_status = status ? ' passing ' : ' failing '
          to_replace = status ? /\bfailing\b/ : /\bpassing\b/
  
          attribute = @root.attribute('class').value.sub(to_replace, desired_status)
          attribute.gsub!(/\s{2,}/, ' ')
          @root.add_attribute('class', attribute)  
        end

        def add_testcase(testcase)
          tests_table = REXML::XPath.first(@root, ".//*[contains(@class, 'tests')]/table")
          details = testcase.failure_details
          if details
            tests_table.push(details)
            tests_table.insert_before(details, testcase.root)
          else
            tests_table.push(testcase.root)
          end
        end

        def duplicate_testcases?
          nonuniq_testcases = testcases
          uniq_testcases = nonuniq_testcases.uniq { |tc| tc.title }
          nonuniq_testcases != uniq_testcases
        end

        def remove_duplicate_testcases
          # Get a list of all the testcases in the report's testsuite
          # and reverse the order so that we'll get the tests that
          # passed _after_ they failed first. That way, when
          # uniq is called, it will grab the first non-repeated test
          # it finds; for duplicated tests (tests that were re-run), it will
          # actually grab the last test that was run of that set.
          #
          # For example, if `testcases` is
          # `['a(passing)', 'b(passing)', 'c(passing)', 'dup1(failing)', 'dup2(failing)', 'dup1(passing)', 'dup2(passing)' ]`
          # then, testcases.reverse will be
          # `['dup2(passing)', 'dup1(passing)', 'dup2(failing)', 'dup1(failing)', 'c(passing)', 'b(passing)', 'a(passing)']`
          # then `uniq_testcases` will be
          # `['dup2(passing)', 'dup1(passing)', 'c(passing)', 'b(passing)', 'a(passing)']`
          nonuniq_testcases = testcases.reverse
          uniq_testcases = nonuniq_testcases.uniq { |tc| tc.title }
          (nonuniq_testcases - uniq_testcases).each do |tc|
            # here, we would be deleting ['dup2(failing)', 'dup1(failing)']
            failure_details = tc.failure_details
            # failure_details can be nil if this is a passing testcase
            tc.root.parent.delete_element(failure_details) unless failure_details.nil?
            tc.root.parent.delete_element(tc.root)
          end
        end

        def collate_testsuite(testsuite)
          given_testcases = testsuite.testcases
          given_testcases.each do |given_testcase|
            existing_testcase = testcase_with_title(given_testcase.title)
            if existing_testcase.nil?
              HtmlTestReport.verbose("\t\tadding testcase\n\t\t\t#{given_testcase.root}")
              unless given_testcase.passing?
                HtmlTestReport.verbose("\t\t\twith failure:\n\t\t\t\t#{given_testcase.failure_details}")
              end
              add_testcase(given_testcase)
            else
              HtmlTestReport.verbose("\t\tupdating testcase\n\t\t\t#{existing_testcase.root}")
              unless given_testcase.passing?
                HtmlTestReport.verbose("\t\t\twith failure:\n\t\t\t\t#{given_testcase.failure_details}")
              end
              existing_testcase.update_testcase(given_testcase)
            end
          end
          set_passing(testcases.all?(&:passing?))
        end
      end

      class TestCase
        attr_reader :root

        def initialize(testcase_element)
          @root = testcase_element
        end

        def title
          REXML::XPath.first(@root, ".//h3[contains(@class, 'title')]/text()").to_s.strip
        end

        def passing?
          @root.attribute('class').value.include?('passing')
        end

        def row_color
          @root.attribute('class').value.include?('odd') ? 'odd' : ''
        end

        def set_row_color(row_color)
          raise 'row_color must either be "odd" or ""' unless ['odd', ''].include?(row_color)

          current_class_attribute = @root.attribute('class').value.sub(/\bodd\b/, '')
          @root.add_attribute('class', current_class_attribute << ' ' << row_color)
        end

        def failure_details
          return nil if @root.attribute('class').value.include?('passing')

          xpath_class_attributes = [
            "contains(concat(' ', @class, ' '), ' details ')",
            "contains(concat(' ', @class, ' '), ' failing ')",
            "contains(concat(' ', @class, ' '), ' #{title} ')"
          ].join(' and ')
          REXML::XPath.first(@root.parent, ".//*[#{xpath_class_attributes}]")
        end

        def remove_failure_details
          details = failure_details
          return if details.nil?
          
          details.parent.delete_element(details)
        end

        def update_testcase(testcase)
          color = row_color
          failure = failure_details
          if failure.nil? && !passing?
            HtmlTestReport.error("\t\t\t\tupdating failing test case that does not have failure_details")
          end
          parent = @root.parent

          failure.parent.delete(failure) unless failure.nil?

          new_failure = testcase.failure_details
          if new_failure && testcase.passing?
            HtmlTestReport.error("\t\t\t\tswapping passing failing test case that _does_have_ failure_details")
          end

          parent.replace_child(@root, testcase.root)
          @root = testcase.root
          unless new_failure.nil?
            parent.insert_after(@root, new_failure)
          end
          set_row_color(color)
        end
      end
    end
  end
end
