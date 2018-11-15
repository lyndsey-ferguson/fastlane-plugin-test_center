module TestCenter
  module Helper
    module RetryingScan
      class Interstitial

        attr_writer :output_directory
        attr_writer :batch

        def initialize(options)
          @output_directory = options[:output_directory]
          @testrun_completed_block = options[:testrun_completed_block]
          @result_bundle = options[:result_bundle]
          @scheme = options[:scheme]
          @batch = options[:batch]
          @reportnamer = options[:reportnamer]
          @xcpretty_json_file_output = ENV['XCPRETTY_JSON_FILE_OUTPUT']
          @parallelize = options[:parallelize]

          before_all
        end

        # TODO: Should we be creating a new interstitial for each batch? yes.
        # Should we clear out the result bundles before each batch? --> should
        # it not be done before all batches? Same with env var for json resports.
        def before_all
          if @result_bundle
            remove_preexisting_test_result_bundles
          end
          set_json_env_if_necessary
          if @parallelize
            @original_derived_data_path = ENV['SCAN_DERIVED_DATA_PATH']
            FileUtils.mkdir_p(@output_directory)
            ENV['SCAN_DERIVED_DATA_PATH'] = Dir.mktmpdir(nil, @output_directory)
          end
        end

        def after_all
          FastlaneCore::UI.message("resetting JSON ENV var to #{@xcpretty_json_file_output}")
          ENV['XCPRETTY_JSON_FILE_OUTPUT'] = @xcpretty_json_file_output
          if @parallelize
            ENV['SCAN_DERIVED_DATA_PATH'] = @original_derived_data_path
          end
        end

        def remove_preexisting_test_result_bundles
          glob_pattern = "#{@output_directory}/.*\.test_result"
          preexisting_test_result_bundles = Dir.glob(glob_pattern)
          FileUtils.rm_rf(preexisting_test_result_bundles)
        end

        def move_test_result_bundle_for_next_run
          if @result_bundle
            built_test_result, moved_test_result = test_result_bundlepaths
            FileUtils.mv(built_test_result, moved_test_result)
          end
        end

        def test_result_bundlepaths
          [
            File.join(@output_directory, @scheme) + '.test_result',
            File.join(@output_directory, @scheme) + "_#{@reportnamer.report_count}.test_result"
          ]
        end

        def reset_simulators
          destinations = Scan.config[:destination]
          simulators = FastlaneCore::DeviceManager.simulators('iOS')
          simulator_ids_to_reset = []
          destinations.each do |destination|
            destination.split(',').each do |destination_pair|
              key, value = destination_pair.split('=')
              if key == 'id'
                simulator_ids_to_reset << value
              end
            end
          end
          simulators_to_reset = simulators.each.select { |simulator| simulator_ids_to_reset.include?(simulator.udid) }
          simulators_to_reset.each do |simulator|
            simulator.reset
          end
        end

        def send_info_for_try(try_count)
          report_filepath = File.join(@output_directory, @reportnamer.junit_last_reportname)

          config = FastlaneCore::Configuration.create(
            Fastlane::Actions::TestsFromJunitAction.available_options,
            {
              junit: File.absolute_path(report_filepath)
            }
          )
          junit_results = Fastlane::Actions::TestsFromJunitAction.run(config)
          info = {
            failed: junit_results[:failed],
            passing: junit_results[:passing],
            batch: @batch,
            try_count: try_count,
            report_filepath: report_filepath
          }

          if @reportnamer.includes_html?
            html_report_filepath = File.join(@output_directory, @reportnamer.html_last_reportname)
            info[:html_report_filepath] = html_report_filepath
          end
          if @reportnamer.includes_json?
            json_report_filepath = File.join(@output_directory, @reportnamer.json_last_reportname)
            info[:json_report_filepath] = json_report_filepath
          end
          if @result_bundle
            test_result_suffix = '.test_result'
            test_result_suffix.prepend("-#{@reportnamer.report_count}") unless @reportnamer.report_count.zero?
            test_result_bundlepath = File.join(@output_directory, @scheme) + test_result_suffix
            info[:test_result_bundlepath] = test_result_bundlepath
          end
          @testrun_completed_block && @testrun_completed_block.call(info)
        end

        def set_json_env_if_necessary
          if @reportnamer && @reportnamer.includes_json?
            ENV['XCPRETTY_JSON_FILE_OUTPUT'] = File.join(
              @output_directory,
              @reportnamer.json_last_reportname
            )
          end
        end

        def finish_try(try_count)
          send_info_for_try(try_count)
          reset_simulators
          ENV['SCAN_DERIVED_DATA_PATH'] = Dir.mktmpdir(nil, @output_directory) if @parallelize
          move_test_result_bundle_for_next_run
          set_json_env_if_necessary
          @reportnamer && @reportnamer.increment
        end
      end
    end
  end
end

