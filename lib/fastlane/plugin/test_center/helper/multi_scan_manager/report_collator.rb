module TestCenter
  module Helper
    module MultiScanManager
      class ReportCollator
        CollateJunitReportsAction = Fastlane::Actions::CollateJunitReportsAction
        CollateHtmlReportsAction = Fastlane::Actions::CollateHtmlReportsAction
        CollateJsonReportsAction = Fastlane::Actions::CollateJsonReportsAction
        CollateTestResultBundlesAction = Fastlane::Actions::CollateTestResultBundlesAction

        def initialize(params)
          @source_reports_directory_glob = params[:source_reports_directory_glob]
          @output_directory = params[:output_directory]
          @reportnamer = params[:reportnamer]
          @scheme = params[:scheme]
          @result_bundle = params[:result_bundle]
          @suffix = params[:suffix] || ''
        end

        def collate
          collate_junit_reports
          collate_html_reports
          collate_json_reports
          collate_test_result_bundles
        end

        def sort_globbed_files(glob)
          files = Dir.glob(glob).map do |relative_filepath|
            File.absolute_path(relative_filepath)
          end
          files.sort! { |f1, f2| File.mtime(f1) <=> File.mtime(f2) }
        end

        def delete_globbed_intermediatefiles(glob)
          retried_reportfiles = Dir.glob(glob)
          FileUtils.rm_f(retried_reportfiles)
        end

        def create_config(klass, options)
          FastlaneCore::Configuration.create(klass.available_options, options)
        end

        def collate_junit_reports
          glob = "#{@source_reports_directory_glob}/#{@reportnamer.junit_fileglob}"
          report_files = sort_globbed_files(glob)
          if report_files.size > 1
            collated_file =  File.absolute_path(File.join(@output_directory, @reportnamer.junit_reportname(@suffix)))
            config = create_config(
              CollateJunitReportsAction,
              {
                reports: report_files,
                collated_report: collated_file
              }
            )
            CollateJunitReportsAction.run(config)
            FileUtils.rm_rf(report_files - [collated_file])
          end
        end

        def collate_html_reports
          return unless @reportnamer.includes_html?

          report_files = sort_globbed_files("#{@source_reports_directory_glob}/#{@reportnamer.html_fileglob}")
          if report_files.size > 1
            collated_file = File.absolute_path(File.join(@output_directory, @reportnamer.html_reportname(@suffix)))
            config = create_config(
              CollateJunitReportsAction,
              {
                reports: report_files,
                collated_report: collated_file
              }
            )
            CollateHtmlReportsAction.run(config)
            FileUtils.rm_rf(report_files - [collated_file])
          end
        end

        def collate_json_reports
          return unless @reportnamer.includes_json?

          report_files = sort_globbed_files("#{@source_reports_directory_glob}/#{@reportnamer.json_fileglob}")
          if report_files.size > 1
            collated_file = File.absolute_path(File.join(@output_directory, @reportnamer.json_reportname(@suffix)))
            config = create_config(
              CollateJsonReportsAction,
              {
                reports: report_files,
                collated_report: collated_file
              }
            )
            CollateJsonReportsAction.run(config)
            FileUtils.rm_rf(report_files - [collated_file])
          end
        end

        def collate_test_result_bundles
          return unless @result_bundle

          test_result_bundlepaths = sort_globbed_files("#{@source_reports_directory_glob}/#{@scheme}*.test_result")
          if test_result_bundlepaths.size > 1
            collated_test_result_bundlepath = File.absolute_path("#{File.join(@output_directory, @scheme)}.test_result'")
            config = create_config(
              CollateTestResultBundlesAction,
              {
                bundles: test_result_bundlepaths,
                collated_bundle: collated_test_result_bundlepath
              }
            )
            CollateTestResultBundlesAction.run(config)
            FileUtils.rm_rf(report_files - [collated_test_result_bundlepath])
          end
        end
      end
    end
  end
end
