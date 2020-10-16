module TestCenter
  module Helper
    require 'fastlane_core/ui/ui.rb'
    require 'fastlane/actions/scan'
    require 'plist'
    require 'set'

    class TestCollector
      attr_reader :xctestrun_path
      attr_reader :batches
      attr_reader :testables

      def initialize(options)
        @invocation_based_tests = options[:invocation_based_tests]
        @swift_test_prefix = options[:swift_test_prefix]

        @xctestrun_path = self.class.xctestrun_filepath(options)
        initialize_batches(options)
      end

      private

      def initialize_batches(options)
        if options[:batches]
          expand_given_batches_to_full_test_identifiers(options)
        else
          derive_batches_from_tests(options)
        end
      end

      def expand_given_batches_to_full_test_identifiers(options)
        @batches = options[:batches]
        testables = Set.new
        @batches.each do |batch|
          expand_test_identifiers(batch)
          batch.each { |t| testables << t.split('/')[0] }
        end
        @testables = testables.to_a
      end

      def derive_batch_count(options)
        batch_count = options.fetch(:batch_count, 1)
        if batch_count == 1 && options.fetch(:parallel_testrun_count, 0) > 1
          # if the batch count is 1, and the users wants parallel runs
          # we *must* set the batch count to the same number of parallel
          # runs or else the desired reports will not be written
          batch_count = options[:parallel_testrun_count]
        end
        batch_count
      end

      def derive_only_testing(options)
        only_testing = options[:only_testing] || self.class.only_testing_from_testplan(options)
        if only_testing && only_testing.kind_of?(String)
          only_testing = only_testing.split(',').map(&:strip)
        end
        only_testing
      end

      def testable_tests_hash_from_options(options)
        testable_tests_hash = Hash.new { |h, k| h[k] = [] }
        only_testing = derive_only_testing(options)
        if only_testing
          expand_test_identifiers(only_testing)
          only_testing.each do |test_identifier|
            testable = test_identifier.split('/')[0]
            testable_tests_hash[testable] << test_identifier
          end
        else
          testable_tests_hash = xctestrun_known_tests.clone
          if options[:skip_testing]
            expand_test_identifiers(options[:skip_testing])
            testable_tests_hash.each do |testable, test_identifiers|
              test_identifiers.replace(test_identifiers - options[:skip_testing])
              testable_tests_hash.delete(testable) if test_identifiers.empty?
            end
          end
        end
        testable_tests_hash
      end

      def derive_batches_from_tests(options)
        @batches = []
        testable_tests_hash = testable_tests_hash_from_options(options)
        @testables = testable_tests_hash.keys
        batch_count = derive_batch_count(options)
        testable_tests_hash.each do |testable, test_identifiers|
          next if test_identifiers.empty?

          if batch_count > 1
            slice_count = [(test_identifiers.length / batch_count.to_f).ceil, 1].max
            test_identifiers.each_slice(slice_count).to_a.each do |batch|
              @batches << batch
            end
          else
            @batches << test_identifiers
          end
        end
      end

      def expand_test_identifiers(test_identifiers)
        all_known_tests = nil
        test_identifiers.each_with_index do |test_identifier, index|
          test_components = test_identifier.split('/')
          is_full_test_identifier = (test_components.size == 3)
          next if is_full_test_identifier

          all_known_tests ||= xctestrun_known_tests.clone

          testsuite = ''
          testable = test_components[0]
          expanded_test_identifiers = []
          if test_components.size == 1
            # this is a testable, also known as a test target. Let's expand it out
            # to all of its tests. Note: a test target can have many testSuites, each
            # with their own testCases.
            if all_known_tests[testable].to_a.empty?
              FastlaneCore::UI.verbose("Unable to expand #{testable} to constituent tests")
              expanded_test_identifiers = [testable]
            else
              expanded_test_identifiers = all_known_tests[testable]
            end
          else
            # this is a testable and a test suite, let's expand it out to all of
            # its testCases. Note: if the user put the same test identifier in more than
            # one place in this array, this could lead to multiple repititions of the same
            # set of test identifiers
            testsuite = test_components[1]
            expanded_test_identifiers = all_known_tests[testable].select do |known_test|
              known_test.split('/')[1] == testsuite
            end
          end
          test_identifiers.delete_at(index)
          test_identifiers.insert(index, *expanded_test_identifiers)
        end
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

      def self.only_testing_from_testplan(options)
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

      def self.default_derived_data_path
        project_derived_data_path = Scan.project.build_settings(key: "BUILT_PRODUCTS_DIR")
        File.expand_path("../../..", project_derived_data_path)
      end

      def self.derived_testrun_path(derived_data_path)
        xctestrun_files = Dir.glob("#{derived_data_path}/Build/Products/*.xctestrun")
        xctestrun_files.sort { |f1, f2| File.mtime(f1) <=> File.mtime(f2) }.last
      end

      def self.xctestrun_filepath(options)
        unless options[:xctestrun] || options[:derived_data_path]
          options[:derived_data_path] = default_derived_data_path
        end
        path = (options[:xctestrun] || derived_testrun_path(options[:derived_data_path]))

        unless path && File.exist?(path)
          FastlaneCore::UI.user_error!("Error: cannot find xctestrun file '#{path}'")
        end
        path
      end
    end
  end
end
