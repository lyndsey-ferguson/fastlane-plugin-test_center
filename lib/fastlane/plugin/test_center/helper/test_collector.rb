module TestCenter
  module Helper
    require 'fastlane_core/ui/ui.rb'
    require 'fastlane/actions/scan'
    require 'plist'

    class TestCollector
      attr_reader :xctestrun_path
      attr_reader :only_testing

      def initialize(options)
        unless options[:xctestrun] || options[:derived_data_path]
          options[:derived_data_path] = default_derived_data_path(options)
        end
        @xctestrun_path = options[:xctestrun] || derived_testrun_path(options[:derived_data_path], options[:scheme])
        unless @xctestrun_path && File.exist?(@xctestrun_path)
          FastlaneCore::UI.user_error!("Error: cannot find xctestrun file '#{@xctestrun_path}'")
        end
        @only_testing = options[:only_testing] || only_testing_from_testplan(options)
        if @only_testing.kind_of?(String)
          @only_testing = @only_testing.split(',')
        end
        @skip_testing = options[:skip_testing]
        @invocation_based_tests = options[:invocation_based_tests]
        @batch_count = options[:batch_count]
        if @batch_count == 1 && options[:parallel_testrun_count] > 1
          @batch_count = options[:parallel_testrun_count]
        end

        @swift_test_prefix = options[:swift_test_prefix]
      end

      def only_testing_from_testplan(options)
        return unless options[:testplan] && options[:scheme]

        config = FastlaneCore::Configuration.create(
          Fastlane::Actions::TestplansFromSchemeAction.available_options,
          {
            workspace: options[:workspace],
            xcodeproj: options[:project],
            scheme: options[:scheme]
          }
        )
        testplans = Fastlane::Actions::TestplansFromSchemeAction.run(config)
        FastlaneCore::UI.verbose("TestCollector found testplans: #{testplans}")
        testplan = testplans.find do |testplan_path|
          %r{(.*/?#{ options[:testplan] })\.xctestplan}.match?(testplan_path)
        end
        FastlaneCore::UI.verbose("  using :testplan option, #{options[:testplan]}, using found one: #{testplan}")

        return if testplan.nil?

        config = FastlaneCore::Configuration.create(
          Fastlane::Actions::TestOptionsFromTestplanAction.available_options,
          {
            testplan: testplan
          }
        )
        test_options = Fastlane::Actions::TestOptionsFromTestplanAction.run(config)
        return test_options[:only_testing]
      end

      def default_derived_data_path(options)
        project_derived_data_path = Scan.project.build_settings(key: "BUILT_PRODUCTS_DIR")
        File.expand_path("../../..", project_derived_data_path)
      end

      def derived_testrun_path(derived_data_path, scheme)
        xctestrun_files = Dir.glob("#{derived_data_path}/Build/Products/*.xctestrun")
        xctestrun_files.sort { |f1, f2| File.mtime(f1) <=> File.mtime(f2) }.last
      end

      def testables
        unless @testables
          if @only_testing
            @testables ||= only_testing_to_testables_tests.keys
          else
            @testables = xctestrun_known_tests.keys
          end
        end
        @testables
      end

      def only_testing_to_testables_tests
        tests = Hash.new { |h, k| h[k] = [] }
        @only_testing.sort.each do |test_identifier|
          testable = test_identifier.split('/', 2)[0]
          tests[testable] << test_identifier
        end
        tests
      end

      def xctestrun_known_tests
        unless @known_tests
          config = FastlaneCore::Configuration.create(
            ::Fastlane::Actions::TestsFromXctestrunAction.available_options,
            {
              xctestrun: @xctestrun_path,
              invocation_based_tests: @invocation_based_tests,
              swift_test_prefix: @swift_test_prefix
            }
          )
          @known_tests = ::Fastlane::Actions::TestsFromXctestrunAction.run(config)
        end
        @known_tests
      end

      # The purpose of this method is to expand :only_testing
      # that has elements that are just the 'testsuite' or
      # are just the 'testable/testsuite'. We want to take
      # those and expand them out to the individual testcases.
      # 'testsuite' => [
      #   'testable/testsuite/testcase1',
      # . 'testable/testsuite/testcase2',
      # . 'testable/testsuite/testcase3'
      # ]
      # OR
      # 'testable/testsuite' => [
      #   'testable/testsuite/testcase1',
      # . 'testable/testsuite/testcase2',
      # . 'testable/testsuite/testcase3'
      # ]
      def expand_testsuites_to_tests(testables_tests)
        # Remember, testable_tests is of the format:
        # {
        #   'testable1' => [
        #     'testsuite1/testcase1',
        #     'testsuite1/testcase2',
        #     'testsuite2/testcase1',
        #     'testsuite2/testcase2',
        #     ...
        #     'testsuiteN/testcase1', ... 'testsuiteN/testcaseM'
        #   ],
        #   ...
        #   'testableO' => [
        #     'testsuite1/testcase1',
        #     'testsuite1/testcase2',
        #     'testsuite2/testcase1',
        #     'testsuite2/testcase2',
        #     ...
        #     'testsuiteN/testcase1', ... 'testsuiteN/testcaseM'
        #   ]
        # }
        return if @invocation_based_tests

        # iterate among all the test identifers for each testable
        # A test identifier is seperated into components by '/'
        # if a test identifier has only 2 separators, it probably is
        # 'testable/testsuite' (but it could be 'testsuite/testcase' )
        all_known_tests = nil
        known_tests = []
        testables_tests.each do |testable, tests|
          tests.each_with_index do |test, index|
            test_components = test.split('/')
            is_full_test_identifier = (test_components.size == 3)
            next if is_full_test_identifier

            all_known_tests ||= xctestrun_known_tests.clone

            testsuite = ''
            if test_components.size == 1
              testsuite = test_components[0]
            else
              testsuite = test_components[1]
            end

            testables_tests[testable][index], all_known_tests[testable] = all_known_tests[testable].partition do |known_test|
              known_test.split('/')[1] == testsuite
            end
          end
          testables_tests[testable].flatten!
        end
      end

      def testables_tests
        unless @testables_tests
          if @only_testing
            @testables_tests = only_testing_to_testables_tests
            expand_testsuites_to_tests(@testables_tests)
          else
            @testables_tests = xctestrun_known_tests
            if @skip_testing
              skipped_testable_tests = Hash.new { |h, k| h[k] = [] }
              @skip_testing.sort.each do |skipped_test_identifier|
                testable = skipped_test_identifier.split('/', 2)[0]
                skipped_testable_tests[testable] << skipped_test_identifier
              end
              @testables_tests.each_key do |testable|
                @testables_tests[testable] -= skipped_testable_tests[testable]
              end
            end
          end
        end

        @testables_tests
      end

      def test_batches
        if @batches.nil?
          @batches = []
          testables.each do |testable|
            testable_tests = testables_tests[testable]
            next if testable_tests.empty?

            if @batch_count > 1
              slice_count = [(testable_tests.length / @batch_count.to_f).ceil, 1].max
              testable_tests.each_slice(slice_count).to_a.each do |tests_batch|
                @batches << tests_batch
              end
            else
              @batches << testable_tests
            end
          end
        end

        @batches
      end
    end
  end
end
