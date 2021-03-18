module TestCenter
  module Helper
    module MultiScanManager
      require_relative '../../actions/collate_junit_reports'
      require_relative '../../actions/collate_html_reports'
      require_relative '../../actions/collate_json_reports'
      require_relative '../../actions/collate_test_result_bundles'
      require_relative '../../actions/collate_xcresults'

      class ReportCollator
        CollateJunitReportsAction = Fastlane::Actions::CollateJunitReportsAction
        CollateHtmlReportsAction = Fastlane::Actions::CollateHtmlReportsAction
        CollateJsonReportsAction = Fastlane::Actions::CollateJsonReportsAction
        CollateTestResultBundlesAction = Fastlane::Actions::CollateTestResultBundlesAction
        CollateXcresultsAction = Fastlane::Actions::CollateXcresultsAction

        def initialize(params)
          FastlaneCore::UI.verbose("ReportCollator.initialize with ':source_reports_directory_glob' of \"#{params[:source_reports_directory_glob]}\"")
          @source_reports_directory_glob = params[:source_reports_directory_glob]
          @output_directory = params[:output_directory]
          @reportnamer = params[:reportnamer]
          @scheme = params[:scheme]
          @result_bundle = params[:result_bundle]
          @suffix = params[:suffix] || ''
        end

        def collate
          FastlaneCore::UI.verbose("ReportCollator collating")
          collate_junit_reports
          collate_html_reports
          collate_json_reports
          collate_test_result_bundles
          collate_xcresult_bundles
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

        # :nocov:
        def create_config(klass, options)
          FastlaneCore::Configuration.create(klass.available_options, options)
        end
        # :nocov:

        def collate_junit_reports
          glob = "#{@source_reports_directory_glob}/#{@reportnamer.junit_fileglob}"
          report_files = sort_globbed_files(glob)
          collated_file =  File.absolute_path(File.join(@output_directory, @reportnamer.junit_reportname(@suffix)))
          if report_files.size > 1
            FastlaneCore::UI.verbose("Collating junit report files #{report_files}")
            config = create_config(
              CollateJunitReportsAction,
              {
                reports: report_files,
                collated_report: collated_file
              }
            )
            CollateJunitReportsAction.run(config)
            FileUtils.rm_rf(report_files - [collated_file])
          elsif report_files.size == 1 && ! File.identical?(report_files.first, collated_file)
            FastlaneCore::UI.verbose("Copying junit report file #{report_files.first}")
            FileUtils.mkdir_p(File.dirname(collated_file))
            FileUtils.mv(report_files.first, collated_file)
          end
        end

        def collate_html_reports
          return unless @reportnamer.includes_html?

          report_files = sort_globbed_files("#{@source_reports_directory_glob}/#{@reportnamer.html_fileglob}")
          collated_file = File.absolute_path(File.join(@output_directory, @reportnamer.html_reportname(@suffix)))
          if report_files.size > 1
            FastlaneCore::UI.verbose("Collating html report files #{report_files}")
            config = create_config(
              CollateJunitReportsAction,
              {
                reports: report_files,
                collated_report: collated_file
              }
            )
            CollateHtmlReportsAction.run(config)
            FileUtils.rm_rf(report_files - [collated_file])
          elsif report_files.size == 1 && ! File.identical?(report_files.first, collated_file)
            FastlaneCore::UI.verbose("Copying html report file #{report_files.first}")
            FileUtils.mkdir_p(File.dirname(collated_file))
            FileUtils.mv(report_files.first, collated_file)
          end
        end

        def collate_json_reports
          return unless @reportnamer.includes_json?

          report_files = sort_globbed_files("#{@source_reports_directory_glob}/#{@reportnamer.json_fileglob}")
          collated_file = File.absolute_path(File.join(@output_directory, @reportnamer.json_reportname(@suffix)))
          if report_files.size > 1
            FastlaneCore::UI.verbose("Collating json report files #{report_files}")
            config = create_config(
              CollateJsonReportsAction,
              {
                reports: report_files,
                collated_report: collated_file
              }
            )
            CollateJsonReportsAction.run(config)
            FileUtils.rm_rf(report_files - [collated_file])
          elsif report_files.size == 1 && ! File.identical?(report_files.first, collated_file)
            FastlaneCore::UI.verbose("Copying json report file #{report_files.first}")
            FileUtils.mkdir_p(File.dirname(collated_file))
            FileUtils.mv(report_files.first, collated_file)
          end
        end

        def collate_test_result_bundles
          return unless @result_bundle

          test_result_bundlepaths = sort_globbed_files("#{@source_reports_directory_glob}/#{@scheme}*.test_result")
          result_bundlename_suffix = ''
          result_bundlename_suffix = "-#{@reportnamer.report_count}" if @reportnamer.report_count > 0
          collated_test_result_bundlepath = File.absolute_path("#{File.join(@output_directory, @scheme)}#{result_bundlename_suffix}.test_result")
          if test_result_bundlepaths.size > 1
            FastlaneCore::UI.verbose("Collating test_result bundles #{test_result_bundlepaths}")
            config = create_config(
              CollateTestResultBundlesAction,
              {
                bundles: test_result_bundlepaths,
                collated_bundle: collated_test_result_bundlepath
              }
            )
            CollateTestResultBundlesAction.run(config)
            FileUtils.rm_rf(test_result_bundlepaths - [collated_test_result_bundlepath])
          elsif test_result_bundlepaths.size == 1 && File.realdirpath(test_result_bundlepaths.first) != File.realdirpath(collated_test_result_bundlepath)
            FastlaneCore::UI.verbose("Copying test_result bundle from #{test_result_bundlepaths.first} to #{collated_test_result_bundlepath}")
            FileUtils.mkdir_p(File.dirname(collated_test_result_bundlepath))
            FileUtils.mv(test_result_bundlepaths.first, collated_test_result_bundlepath)
          end
        end

        def collate_xcresult_bundles
          return unless @reportnamer.includes_xcresult?

          test_xcresult_bundlepaths = sort_globbed_files("#{@source_reports_directory_glob}/#{@reportnamer.xcresult_fileglob}")
          xcresult_bundlename_suffix = ''
          xcresult_bundlename_suffix = "-#{@reportnamer.report_count}" if @reportnamer.report_count > 0
          collated_xcresult_bundlepath = File.absolute_path("#{File.join(@output_directory, @reportnamer.xcresult_bundlename(@suffix))}")
          if test_xcresult_bundlepaths.size > 1
            FastlaneCore::UI.verbose("Collating xcresult bundles #{test_xcresult_bundlepaths}")
            config = create_config(
              CollateXcresultsAction,
              {
                xcresults: test_xcresult_bundlepaths,
                collated_xcresult: collated_xcresult_bundlepath
              }
            )
            CollateXcresultsAction.run(config)
            FileUtils.rm_rf(test_xcresult_bundlepaths - [collated_xcresult_bundlepath])
          elsif test_xcresult_bundlepaths.size == 1 && File.realdirpath(test_xcresult_bundlepaths.first.downcase) != File.realdirpath(collated_xcresult_bundlepath.downcase)
            FastlaneCore::UI.verbose("Copying xcresult bundle from #{test_xcresult_bundlepaths.first} to #{collated_xcresult_bundlepath}")
            FileUtils.mkdir_p(File.dirname(collated_xcresult_bundlepath))
            FileUtils.mv(test_xcresult_bundlepaths.first, collated_xcresult_bundlepath)
          end
        end
      end
    end
  end
end
