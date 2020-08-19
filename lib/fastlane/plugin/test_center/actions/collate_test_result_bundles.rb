module Fastlane
  module Actions
    class CollateTestResultBundlesAction < Action
      require 'plist'

      def self.run(params)
        test_result_bundlepaths = params[:bundles]
        base_bundle_path = test_result_bundlepaths[0]

        return if collate_version3_formatted_bundles(params)

        if test_result_bundlepaths.size > 1
          base_bundle_path = Dir.mktmpdir(['base', '.test_result'])
          FileUtils.cp_r(File.join(test_result_bundlepaths[0], '.'), base_bundle_path)
          test_result_bundlepaths.shift
          test_result_bundlepaths.each do |other_bundlepath|
            collate_bundles(base_bundle_path, other_bundlepath)
          end
        end
        FileUtils.rm_rf(params[:collated_bundle])
        FileUtils.cp_r(base_bundle_path, params[:collated_bundle])
        UI.message("Finished collating test_result bundle to '#{params[:collated_bundle]}'")
      end

      def self.collate_version3_formatted_bundles(params)
        test_result_bundlepaths = params[:bundles]
        found_version3_format_bundle = test_result_bundlepaths.any? do |test_result_bundlepath|
          is_bundle_format_3?(test_result_bundlepath)
        end
        
        if found_version3_format_bundle
          FastlaneCore::UI.verbose("result bundles are of format version 3")
          `xcrun xcresulttool version 2> /dev/null`
          unless $?.exitstatus.zero?
            UI.user_error!("""
              Unable to collate version 3 format test_result bundle without the xcrun xcresulttool.
              Please install and select Xcode 11, and then run the command again.""")
          end
          xcresulttool_merge(params)
          return true
        end
        FastlaneCore::UI.verbose("result bundles are NOT of format version 3")
        return false
      end

      def self.xcresulttool_merge(params)
        test_result_bundlepaths = params[:bundles]
        collated_bundlepath = File.expand_path(params[:collated_bundle])
        Dir.mktmpdir do |dir|
          tmp_xcresult_bundlepaths = []
          test_result_bundlepaths.each do |test_result_bundlepath|
            bundlename = File.basename(test_result_bundlepath)
            # Note: the `xcresulttool` requires that the bundle names end in `.xcresult`.
            tmp_xcresult_bundlepath = Dir.mktmpdir([bundlename, '.xcresult'])
            FileUtils.rmdir([tmp_xcresult_bundlepath])
            FileUtils.symlink(test_result_bundlepath, "#{tmp_xcresult_bundlepath}", force: true)
            tmp_xcresult_bundlepaths << tmp_xcresult_bundlepath
          end
          tmp_collated_bundlepath = File.join(dir, File.basename(collated_bundlepath))
          xcresulttool_cmd = 'xcrun xcresulttool merge '
          xcresulttool_cmd += tmp_xcresult_bundlepaths.map(&:shellescape).join(' ')
          xcresulttool_cmd += " --output-path #{tmp_collated_bundlepath.shellescape}"
          UI.message(xcresulttool_cmd)
          sh(xcresulttool_cmd)
          FileUtils.safe_unlink(tmp_xcresult_bundlepaths)
          FileUtils.rm_rf(collated_bundlepath)
          FileUtils.cp_r(tmp_collated_bundlepath, collated_bundlepath)
          UI.message("Finished collating test_result bundle to '#{collated_bundlepath}'")
        end
      end

      def self.is_bundle_format_3?(bundle_path)
        infoplist_filepath = File.join(bundle_path, 'Info.plist')
        if File.exist?(infoplist_filepath)
          base_infoplist = Plist.parse_xml(infoplist_filepath)
          if base_infoplist.key?('version')
            return true if base_infoplist.dig('version', 'major') > 2
          end
        end
        false
      end

      def self.collate_bundles(base_bundle_path, other_bundle_path)
        Dir.foreach(other_bundle_path) do |child_item|
          if child_item == 'Info.plist'
            collate_infoplist(
              File.join(base_bundle_path, child_item),
              File.join(other_bundle_path, child_item)
            )
          elsif /\d_Test/ =~ child_item
            test_target_path = File.join(base_bundle_path, child_item)
            other_target_path = File.join(other_bundle_path, child_item)
            Dir.foreach(other_target_path) do |grandchild_item|
              collate_bundle(test_target_path, other_target_path, grandchild_item)
            end
          else
            collate_bundle(base_bundle_path, other_bundle_path, child_item)
          end
        end
      end

      def self.collate_bundle(base_bundle_path, other_bundle_path, child_item_name)
        if %w{Attachments Diagnostics}.include?(child_item_name)
          FileUtils.cp_r(
            File.join(other_bundle_path, child_item_name, '.'),
            File.join(base_bundle_path, child_item_name)
          )
        elsif child_item_name.end_with?('.xcactivitylog')
          concatenate_zipped_activitylogs(
            File.join(base_bundle_path, child_item_name),
            File.join(other_bundle_path, child_item_name)
          )
        elsif child_item_name.end_with?('TestSummaries.plist')
          collate_testsummaries_plist(
            File.join(base_bundle_path, child_item_name),
            File.join(other_bundle_path, child_item_name)
          )
        end
      end

      def self.concatenate_zipped_activitylogs(base_activity_log_path, other_activity_log_path)
        gunzipped_base_filepath = File.join(
          File.dirname(base_activity_log_path),
          File.basename(base_activity_log_path, '.*')
        )
        gunzipped_other_filepath = File.join(
          File.dirname(other_activity_log_path),
          File.basename(other_activity_log_path, '.*')
        )
        sh("gunzip -k -S .xcactivitylog '#{other_activity_log_path}'", print_command: false, print_command_output: false)
        sh("gunzip -S .xcactivitylog '#{base_activity_log_path}'", print_command: false, print_command_output: false)
        sh("cat '#{gunzipped_other_filepath}' > '#{gunzipped_base_filepath}'", print_command: false, print_command_output: false)
        FileUtils.rm(gunzipped_other_filepath)
        sh("gzip -S .xcactivitylog '#{gunzipped_base_filepath}'", print_command: false, print_command_output: false)
      end

      def self.collate_testsummaries_plist(base_testsummaries_plist_filepath, other_testsummaries_plist_filepath)
        if File.exist?(base_testsummaries_plist_filepath)
          base_testsummaries_plist = Plist.parse_xml(base_testsummaries_plist_filepath)
          other_testsummaries_plist = Plist.parse_xml(other_testsummaries_plist_filepath)
          base_testsummaries_plist['TestableSummaries'].zip(other_testsummaries_plist['TestableSummaries']).each do |base_testable_summary, other_testable_summary|
            unless base_testable_summary.key?('PreviousTests')
              base_testable_summary['PreviousTests'] = []
            end
            base_testable_summary['PreviousTests'].concat(base_testable_summary['Tests'] || [])
            base_testable_summary['Tests'] = other_testable_summary['Tests']
          end
          Plist::Emit.save_plist(base_testsummaries_plist, base_testsummaries_plist_filepath)
        else
          FileUtils.cp(other_testsummaries_plist, base_testsummaries_plist)
        end
      end

      def self.collate_infoplist(base_infoplist_filepath, other_infoplist_filepath)
        if File.exist?(base_infoplist_filepath)
          base_infoplist = Plist.parse_xml(base_infoplist_filepath)
          other_infoplist = Plist.parse_xml(other_infoplist_filepath)
          other_infoplist['Actions'].zip(base_infoplist['Actions']).each do |other_action, base_action|
            if other_action['Title'] != base_action['Title']
              raise 'Info.plist Actions do not align: cannot collate'
            end
            base_action['EndedTime'] = other_action['EndedTime']
            base_action['ActionResult']['TestsFailedCount'] = other_action['ActionResult']['TestsFailedCount']
          end
          Plist::Emit.save_plist(base_infoplist, base_infoplist_filepath)
        else
          FileUtils.cp(other_infoplist_filepath, base_infoplist_filepath)
        end
      end

      #####################################################
      # @!group Documentation
      #####################################################

      # :nocov:
      def self.description
        "🔸 Combines multiple test_result bundles into one test_result bundle"
      end

      def self.details
        "The first test_result bundle is used as the base bundle. " \
        "Testcases that failed in previous bundles that no longer appear in " \
        "later bundles are assumed to have passed in a re-run, thus not appearing " \
        "in the collated test_result bundle. " \
        "This is done because it is assumed that fragile tests, when " \
        "re-run will often succeed due to less interference from other " \
        "tests and the subsequent test_result bundles will have fewer failing tests."
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :bundles,
            env_name: 'COLLATE_TEST_RESULT_BUNDLES_BUNDLES',
            description: 'An array of test_result bundles to collate. The first bundle is used as the base into which other bundles are merged in',
            optional: false,
            type: Array,
            verify_block: proc do |bundles|
              UI.user_error!('No test_result bundles found') if bundles.empty?
              bundles.each do |bundle|
                UI.user_error!("Error: test_result bundle not found: '#{bundle}'") unless Dir.exist?(bundle)
              end
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :collated_bundle,
            env_name: 'COLLATE_TEST_RESULT_BUNDLES_COLLATED_BUNDLE',
            description: 'The final test_result bundle where all testcases will be merged into',
            optional: true,
            default_value: 'result.test_result',
            type: String
          )
        ]
      end

      def self.example_code
        [
          "
          UI.important(
            'example: ' \\
            'collate the test_result bundles to a temporary bundle \"result.test_result\"'
          )
          bundles = Dir['../spec/fixtures/*.test_result'].map { |relpath| File.absolute_path(relpath) }
          Dir.mktmpdir('test_output') do |dir|
            collate_test_result_bundles(
              bundles: bundles,
              collated_bundle: File.join(dir, 'result.test_result')
            )
          end
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
