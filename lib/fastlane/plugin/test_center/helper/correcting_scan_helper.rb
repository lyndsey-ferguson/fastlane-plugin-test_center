module TestCenter
  module Helper
    require 'fastlane_core/ui/ui.rb'
    require 'plist'

    class CorrectingScanHelper
      def initialize(multi_scan_options)
        @batch_count = multi_scan_options[:batch_count] || 1
        @output_directory = multi_scan_options[:output_directory] || 'test_results'
        @try_count = multi_scan_options[:try_count]
        @given_custom_report_file_name = multi_scan_options[:custom_report_file_name]
        @given_output_types = multi_scan_options[:output_types]
        @given_output_files = multi_scan_options[:output_files]
        @scan_options = multi_scan_options.reject do |option, _|
          %i[output_directory only_testing skip_testing try_count batch_count custom_report_file_name fail_build].include?(option)
        end
        @test_collector = TestCollector.new(multi_scan_options)
      end

      def scan
        tests_passed = true
        @testables_count = @test_collector.testables.size
        @test_collector.testables.each do |testable|
          tests_passed = scan_testable(testable) && tests_passed
        end
        tests_passed
      end

      def scan_testable(testable)
        tests_passed = true
        reportnamer = ReportNameHelper.new(
          @given_output_types,
          @given_output_files,
          @given_custom_report_file_name
        )
        output_directory = @output_directory
        if @batch_count > 1 || @testables_count > 1
          testable_tests = @test_collector.testables_tests[testable]
          testable_tests.each_slice((testable_tests.length / @batch_count.to_f).round).to_a.each do |tests_batch|
            if @testables_count > 1
              output_directory = File.join(@output_directory, "results-#{testable}")
            end
            FastlaneCore::UI.header("Starting test run on testable '#{testable}'")
            tests_passed = correcting_scan(
              {
                only_testing: tests_batch,
                output_directory: output_directory
              },
              reportnamer
            ) && tests_passed
            reportnamer.increment
          end
        else
          options = {
            output_directory: output_directory
          }
          options[:skip_testing] = @skip_testing if @skip_testing
          tests_passed = correcting_scan(options, reportnamer) && tests_passed
        end
        collate_reports(output_directory, reportnamer)
        tests_passed
      end

      def collate_reports(output_directory, reportnamer)
        report_files = Dir.glob("#{output_directory}/*#{reportnamer.junit_filextension}").map do |relative_filepath|
          File.absolute_path(relative_filepath)
        end
        if report_files.size > 1
          config = FastlaneCore::Configuration.create(
            Fastlane::Actions::CollateJunitReportsAction.available_options,
            {
              reports: report_files.sort { |f1, f2| File.mtime(f1) <=> File.mtime(f2) },
              collated_report: File.absolute_path(File.join(output_directory, reportnamer.junit_reportname))
            }
          )
          Fastlane::Actions::CollateJunitReportsAction.run(config)
        end
        FileUtils.rm_f(Dir.glob("#{output_directory}/**/*-[1-9]*#{reportnamer.junit_filextension}"))
      end

      def correcting_scan(scan_run_options, reportnamer)
        scan_options = @scan_options.merge(scan_run_options)
        try_count = 0
        tests_passed = true
        begin
          try_count += 1
          config = FastlaneCore::Configuration.create(
            Fastlane::Actions::ScanAction.available_options,
            scan_options.merge(reportnamer.scan_options)
          )
          quit_simulators
          Fastlane::Actions::ScanAction.run(config)
        rescue FastlaneCore::Interface::FastlaneTestFailure => e
          FastlaneCore::UI.verbose("Scan failed with #{e}")
          if try_count < @try_count
            report_filepath = File.join(scan_options[:output_directory], reportnamer.junit_last_reportname)
            config = FastlaneCore::Configuration.create(
              Fastlane::Actions::TestsFromJunitAction.available_options,
              {
                junit: File.absolute_path(report_filepath)
              }
            )
            failed_tests = Fastlane::Actions::TestsFromJunitAction.run(config)[:failed]
            scan_options[:only_testing] = failed_tests.map(&:shellescape)
            FastlaneCore::UI.message('Re-running scan on only failed tests')
            reportnamer.increment
            retry
          end
          tests_passed = false
        end
        tests_passed
      end

      def quit_simulators
        Fastlane::Actions.sh("killall -9 'iPhone Simulator' 'Simulator' 'SimulatorBridge' &> /dev/null || true", log: false)
        launchctl_list_count = 0
        while Fastlane::Actions.sh('launchctl list | grep com.apple.CoreSimulator.CoreSimulatorService || true', log: false) != ''
          break if (launchctl_list_count += 1) > 10
          Fastlane::Actions.sh('launchctl remove com.apple.CoreSimulator.CoreSimulatorService &> /dev/null || true', log: false)
          sleep(1)
        end
      end
    end
  end
end
