module Fastlane
  module Actions
    class TestsFromXctestrunAction < Action
      def self.run(params)
        return xctestrun_tests(params[:xctestrun])
      end

      def self.xctestrun_tests(xctestrun_path)
        xctestrun = Plist.parse_xml(xctestrun_path)
        xctestrun_rootpath = File.dirname(xctestrun_path)
        tests = Hash.new([])
        xctestrun.each do |testable_name, xctestrun_config|
          test_identifiers = XCTestList.tests(xctest_bundle_path(xctestrun_rootpath, xctestrun_config))
          if xctestrun_config.key?('SkipTestIdentifiers')
            test_identifiers.reject! { |test_identifier| xctestrun_config['SkipTestIdentifiers'].include?(test_identifier) }
          end
          tests[testable_name] = test_identifiers.map do |test_identifier|
            "#{testable_name.shellescape}/#{test_identifier}"
          end
        end
        tests
      end

      def self.xctest_bundle_path(xctestrun_rootpath, xctestrun_config)
        xctest_host_path = xctestrun_config['TestHostPath'].sub('__TESTROOT__', xctestrun_rootpath)
        xctestrun_config['TestBundlePath'].sub!('__TESTHOST__', xctest_host_path)
        xctestrun_config['TestBundlePath'].sub('__TESTROOT__', xctestrun_rootpath)
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Retrieves all of the tests from xctest bundles referenced by the xctestrun file"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :xctestrun,
            env_name: "FL_SUPPRESS_TESTS_FROM_XCTESTRUN_FILE",
            description: "The xctestrun file to use to find where the xctest bundle file is for test retrieval",
            verify_block: proc do |path|
              UI.user_error!("Error: cannot find the xctestrun file '#{path}'") unless File.exist?(path)
            end
          )
        ]
      end

      def self.return_value
        "A Hash of testable => tests, where testable is the name of the test target and tests is an array of test identifiers"
      end

      def self.authors
        ["lyndsey-ferguson/lyndseydf"]
      end

      def self.is_supported?(platform)
        platform == :ios
      end
    end
  end
end
