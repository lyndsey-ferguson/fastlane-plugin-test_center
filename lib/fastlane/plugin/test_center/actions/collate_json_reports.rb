module Fastlane
  module Actions
    class CollateJsonReportsAction < Action
      require 'json'

      def self.run(params)
        report_filepaths = params[:reports]
        if report_filepaths.size == 1
          FileUtils.cp(report_filepaths[0], params[:collated_report])
        else
          base_report_json = JSON.parse(File.read(report_filepaths.shift))
          report_filepaths.each do |report_file|
            report_json = JSON.parse(File.read(report_file))
            update_previous_test_failures(base_report_json)
            merge_reports(base_report_json, report_json)
          end
          File.open(params[:collated_report], 'w') do |f|
            f.write(JSON.pretty_generate(base_report_json))
          end
        end
      end

      def self.merge_reports(base_report, other_report)
        base_report.each_key do |key|
          unless %w(previous_tests_failures tests_failures tests_summary_messages).include?(key)
            base_report[key].concat(other_report[key])
          end
        end
        base_report["tests_failures"] = other_report["tests_failures"]
        update_failed_tests_count(base_report, other_report)
        update_time(base_report, other_report)
        update_unexpected_failures(base_report, other_report)
      end

      def self.update_time(base_report, other_report)
        base_test_time, base_total_time = times_from_summary(base_report['tests_summary_messages'][0])
        other_test_time, other_total_time = times_from_summary(other_report['tests_summary_messages'][0])
        time_regex = '(?:\d|\.)+'

        test_time_sum = (base_test_time + other_test_time).round(3)
        total_time_sum = (base_total_time + other_total_time).round(3)
        base_report['tests_summary_messages'][0].sub!(
          /in #{time_regex} \(#{time_regex}\) seconds/,
          "in #{test_time_sum} (#{total_time_sum}) seconds"
        )
      end

      def self.update_unexpected_failures(base_report, other_report)
        base_unexpected_failures = unexpected_failures_from_summary(base_report['tests_summary_messages'][0])
        other_unexpected_failures = unexpected_failures_from_summary(other_report['tests_summary_messages'][0])
        base_report['tests_summary_messages'][0].sub!(
          /\(\d+ unexpected\)/,
          "(#{base_unexpected_failures + other_unexpected_failures} unexpected)"
        )
      end

      def self.unexpected_failures_from_summary(summary)
        /\((?<unexpected_failures>\d+) unexpected\)/ =~ summary
        unexpected_failures.to_i
      end

      def self.times_from_summary(summary)
        time_regex = '(?:\d|\.)+'
        match = /in (?<test_time>#{time_regex}) \((?<total_time>#{time_regex})\) seconds/.match(summary)
        return [
          match['test_time'].to_f,
          match['total_time'].to_f
        ]
      end

      def self.update_failed_tests_count(base_report, other_report)
        /\s+Executed \d+ tests?, with (?<failed_test_count>\d+) failures?/ =~ other_report['tests_summary_messages'][0]

        base_report['tests_summary_messages'][0].sub!(
          /(\d+) failure/,
          "#{failed_test_count} failure"
        )
      end

      def self.update_previous_test_failures(base_report)
        previous_tests_failures = base_report['previous_tests_failures']
        if previous_tests_failures
          tests_failures = base_report['tests_failures']
          tests_failures.each do |failure_suite, failures|
            if previous_tests_failures.key?(failure_suite)
              previous_tests_failures[failure_suite].concat(failures)
            else
              previous_tests_failures[failure_suite] = failures
            end
          end
        else
          base_report['previous_tests_failures'] = base_report['tests_failures'] || {}
        end
        base_report.delete('tests_failures')
      end

      #####################################################
      # @!group Documentation
      #####################################################

      # :nocov:
      def self.description
        "🔹 Combines multiple json report files into one json report file"
      end

      def self.details
        "The first JSON report is used as the base report. Due to the nature of " \
        "xcpretty JSON reports, only the failing test cases are recorded. " \
        "Testcases that failed in previous reports that no longer appear in " \
        "later reports are assumed to have passed in a re-run, thus not appearing " \
        "in the collated report. " \
        "This is done because it is assumed that fragile tests, when " \
        "re-run will often succeed due to less interference from other " \
        "tests and the subsequent JSON reports will have fewer failing tests." \
        ""
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :reports,
            env_name: 'COLLATE_JSON_REPORTS_REPORTS',
            description: 'An array of JSON reports to collate. The first report is used as the base into which other reports are merged in',
            optional: false,
            type: Array,
            verify_block: proc do |reports|
              UI.user_error!('No JSON report files found') if reports.empty?
              reports.each do |report|
                UI.user_error!("Error: JSON report not found: '#{report}'") unless File.exist?(report)
              end
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :collated_report,
            env_name: 'COLLATE_JSON_REPORTS_COLLATED_REPORT',
            description: 'The final JSON report file where all testcases will be merged into',
            optional: true,
            default_value: 'result.json',
            type: String
          )
        ]
      end

      def self.example_code
        [
          "
          UI.important(
            'example: ' \\
            'collate the json reports to a temporary file \"result.json\"'
          )
          reports = Dir['../spec/fixtures/report*.json'].map { |relpath| File.absolute_path(relpath) }
          collate_json_reports(
            reports: reports,
            collated_report: File.join(Dir.mktmpdir, 'result.json')
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
