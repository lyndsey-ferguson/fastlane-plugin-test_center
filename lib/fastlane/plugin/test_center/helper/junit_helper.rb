require_relative 'xcodebuild_string'

module TestCenter
  module Helper
    module XcodeJunit
      require 'xcodeproj'

      class Report
        def initialize(junit_report_filepath)
          report_file = File.open(junit_report_filepath) { |f| REXML::Document.new(f) }
          FastlaneCore::UI.user_error!("Malformed XML test report file given") if report_file.root.nil?
          FastlaneCore::UI.user_error!("Valid XML file is not an Xcode test report") if report_file.get_elements('testsuites').empty?

          @testables = []
          report_file.elements.each('testsuites') do |testsuites_element|
            @testables << Testable.new(testsuites_element)
          end
        end

        def testables
          return @testables
        end
      end

      class Testable
        def initialize(xml_element)
          @root = xml_element
          @testsuites = []
          @root.elements.each('testsuite') do |testsuite_element|
            @testsuites << TestSuite.new(testsuite_element)
          end
        end

        def name
          return @root.attribute('name').value
        end

        def testsuites
          return @testsuites
        end
      end

      class TestSuite
        def initialize(xml_element)
          @root = xml_element
          @testcases = []
          @root.elements.each('testcase') do |testcase_element|
            @testcases << TestCase.new(testcase_element)
          end
        end

        def name
          return @root.attribute('name').value
        end

        def identifier
          name.testsuite
        end

        def is_swift?
          return name.include?('.')
        end

        def testcases
          return @testcases
        end
      end

      class TestCase
        attr_reader :identifier
        attr_reader :skipped_test
        attr_reader :message
        attr_reader :location

        def initialize(xml_element)
          @root = xml_element
          name = xml_element.attribute('name').value
          failure_element = xml_element.elements['failure']
          if failure_element
            @message = failure_element.attribute('message')&.value || ''
            @location = failure_element.text || ''
          end
          full_testsuite = xml_element.parent.attribute('name').value
          testsuite = full_testsuite.testsuite
          is_swift = full_testsuite.testsuite_swift?

          testable_filename = xml_element.parent.parent.attribute('name').value
          testable = File.basename(testable_filename, '.xctest')
          @identifier = "#{testable}/#{testsuite}/#{name}"
          @skipped_test = Xcodeproj::XCScheme::TestAction::TestableReference::SkippedTest.new
          @skipped_test.identifier = "#{testsuite}/#{name}#{'()' if is_swift}"
          @passed = xml_element.get_elements('failure').size.zero?
        end

        def passed?
          @passed
        end
      end
    end
  end
end
