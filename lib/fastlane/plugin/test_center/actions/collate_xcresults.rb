module Fastlane
  module Actions
    class CollateXcresultsAction < Action
      require 'tempfile'

      def self.run(params)
        unless FastlaneCore::Helper.xcode_at_least?(11)
          FastlaneCore::UI.error("Error: Xcode 11 is required to run this action")
          return
        end
        commands_run = ''
  
        xcresult_bundlepaths = params[:xcresults]
        base_xcresult_path = xcresult_bundlepaths[0]
        
        tmp_collated_xcresult_bundle = Tempfile.new(['collated_result_', '.xcresult'])
        tmp_collated_xcresult_bundlepath = tmp_collated_xcresult_bundle.path
        tmp_collated_xcresult_bundle.unlink

        if xcresult_bundlepaths.size > 1
          command = [
            'xcrun',
            'xcresulttool',
            'merge',
            xcresult_bundlepaths,
            '--output-path',
            tmp_collated_xcresult_bundlepath
          ].flatten
          commands_run = sh(*command)

          FileUtils.rm_rf(params[:collated_xcresult])
          FileUtils.cp_r(tmp_collated_xcresult_bundlepath, params[:collated_xcresult])
        elsif File.realdirpath(xcresult_bundlepaths.first) != File.realdirpath(params[:collated_xcresult])
          FileUtils.rm_rf(params[:collated_xcresult])
          FileUtils.cp_r(base_xcresult_path, params[:collated_xcresult])
        end

        UI.message("Finished collating xcresults to '#{params[:collated_xcresult]}'")
        UI.verbose("  final xcresults: #{other_action.tests_from_xcresult(xcresult: params[:collated_xcresult])}")

        commands_run
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "🔸 Combines multiple xcresult bundles into one xcresult bundle"
      end

      def self.details
        "The first xcresult bundle is used as the base bundle. " \
        "Testcases that failed in previous bundles that no longer appear in " \
        "later bundles are assumed to have passed in a re-run, thus not appearing " \
        "in the collated xcresult bundle. " \
        "This is done because it is assumed that fragile tests, when " \
        "re-run will often succeed due to less interference from other " \
        "tests and the subsequent xcresult bundles will have fewer failing tests."
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :xcresults,
            env_name: 'COLLATE_XCRESULTS',
            description: 'An array of xcresult bundles to collate',
            optional: false,
            type: Array,
            verify_block: proc do |xcresult_bundles|
              UI.user_error!('No xcresult bundles found') if xcresult_bundles.empty?
              xcresult_bundles.each do |xcresult_bundle|
                UI.user_error!("Error: xcresult bundle not found: '#{xcresult_bundle}'") unless Dir.exist?(xcresult_bundle)
              end
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :collated_xcresult,
            env_name: 'COLLATE_XCRESULTS',
            description: 'The merged xcresult bundle',
            optional: true,
            default_value: 'result.xcresult',
            type: String
          )
        ]
      end

      def self.example_code
        [
          "
          require 'tmpdir'

          UI.important(
            'example: ' \\
            'collate the xcresult bundles to a temporary xcresult bundle \"result.xcresult\"'
          )
          xcresults = Dir['../spec/fixtures/AtomicBoyUITests-batch-{3,4}/result.xcresult'].map { |relpath| File.absolute_path(relpath) }
          Dir.mktmpdir('test_output') do |dir|
            collate_xcresults(
              xcresults: xcresults,
              collated_xcresult: File.join(dir, 'result.xcresult')
            )
          end
          "
        ]
      end

      def self.authors
        ["lyndsey-ferguson/@lyndseydf"]
      end

      def self.is_supported?(platform)
        [:ios, :mac].include?(platform)
      end
    end
  end
end
