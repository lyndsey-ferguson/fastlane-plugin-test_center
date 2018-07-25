

<img src="docs/test_center_banner.png" />

# test_center plugin 🎯
[![fastlane Plugin Badge](https://rawcdn.githack.com/fastlane/fastlane/master/fastlane/assets/plugin-badge.svg)](https://rubygems.org/gems/fastlane-plugin-test_center)

Have you ever spent too much time trying to fix fragile tests only to give up with nothing real to show? Use the `fastlane` actions from `test_center` to remove internal and external interference from your tests, so that you can focus on what makes 💰: features that customers love 😍.

<p align="center">
  <a href="#quick-start">Quick Start</a> |
  <a href="#overview">Overview</a> |
  <a href="#issues-and-feedback">Issues and Feedback</a> |
  <a href="#contributing">Contributing</a> |
  <a href="#license">License</a>
</p>

<img src="docs/multi_scan.gif" />

## Quick Start

This project is a [_fastlane_](https://github.com/fastlane/fastlane) plugin. To get started with `fastlane-plugin-test_center`, add it to your project by running:

```bash
fastlane add_plugin test_center
```

Add this example 'lane' to your `Fastfile`, change `MY_XCODE_PROJECT_FILEPATH` to point to your project path, and change the option `scheme: AtomicBoy` in the call to `multi_scan` to be the name of your Xcode projects Scheme:

```ruby

################################################################################
# An example of how one can use the plugin's :multi_scan action to run tests
# that have not yet passed (up to 3 times). If, after the 3 runs of the tests, there
# are still failing tests, print out the number of tests that are still failing.
#
# For a walkthrough to write a lane that can run tests up to 3 times, suppress
# the failing tests in the Xcode project, and create a Github Pull Request, see:
# https://github.com/lyndsey-ferguson/fastlane-plugin-test_center/blob/master/docs/WALKTHROUGH.md
################################################################################

MY_XCODE_PROJECT_FILEPATH = File.absolute_path('../AtomicBoy/AtomicBoy.xcodeproj')
lane :sweep do
  test_run_block = lambda do |testrun_info|
    failed_test_count = testrun_info[:failed].size
    
    if failed_test_count > 0
      UI.important('The run of tests would finish with failures due to fragile tests here.')

      try_attempt = testrun_info[:try_count]
      if try_attempt < 3
        UI.header('Since we are using :multi_scan, we can re-run just those failing tests!')
      end
    end
  end
  
  result = multi_scan(
    project: MY_XCODE_PROJECT_FILEPATH,
    try_count: 3,
    fail_build: false,
    scheme: 'AtomicBoy',
    testrun_completed_block: test_run_block
  )
  unless result[:failed_testcount].zero?
    UI.info("There are #{result[:failed_testcount]} legitimate failing tests")
  end
end
```

## Overview

This plugin makes testing your iOS app easier by providing you actions that give you greater control over everthing related to testing your app. 

`multi_scan` began when I engineered an action to only re-run the failed tests in order to determine which ones were truly failing, or just failing randomly due to a fragile infrastructure. This action morphed into an entire plugin with many actions related to tests.

This fastlane plugin includes the following actions:
- [`multi_scan`](#multi_scan): gives you control over how your tests are exercised.
- [`suppress_tests_from_junit`](#suppress_tests_from_junit): from a test report, suppresses tests in your project.
- [`suppress_tests`](#suppress_tests): from a provided list, suppresses tests in your project.
- [`suppressed_tests`](#suppressed_tests): returns a list of the suppressed tests in your project.
- [`tests_from_junit`](#tests_from_junit): from a test report, returns lists of passing and failed tests.
- [`tests_from_xctestrun`](#tests_from_xctestrun): from an xctestrun file, returns a list of tests for each of its test targets.
- [`collate_junit_reports`](#collate_junit_reports): combines multiple junit test reports into one report.
- [`collate_html_reports`](#collate_html_reports): combines multiple html test reports into one report.
- [`collate_json_reports`](#collate_json_reports): combines multiple json test reports into one report.
- [`collate_test_result_bundles`](#collate_test_result_bundles): combines multiple test_result bundles into one test_result bundle.

### multi_scan 🎉

Use `:multi_scan` intead of `:scan` to improve the usefulness of iOS test results, inspect partial results periodically during a test run, and provide better results reporting. 

#### Improving Usefulness

Over time, your tests can change the state of your application in unexpected ways that cause other tests to fail randomly. Or, the tools and infrastructure for testing are the root causes of random test failures. The test results may not truly reflect how the product code is working.

Rather than wasting time trying to account for instable tools, or trying to tweak your test code ad-nauseum to get a passing result reliably, just use the `:try_count` option to run `:scan` multiple times, running only the tests that failed each time. This ensures that any _fragility_ is ironed out over a number of "tries". The end result is that only the truly failing tests appear.

Another issue that can cause tests to incorrectly fail comes from an issue with the iOS Simulator. If you provide a huge number of tests to the iOS Simulator, it can exhaust the available resources and cause it to fail large numbers of tests. You can get around this by running your tests in batches using the `:batch_count` option in order to lighten the load on the simulator.

#### Inspect Partial Results

If you have a large number of tests, and you want to inspect the overall status of how test runs are progressing, you can use the `:testrun_completed_block` callback to bailout early or make adjustments on how your tests are exercised.

#### Better Results Reporting

Do you have multiple test targets and the normal operation of `:scan` is providing you a test report that implies that all the tests ran in just one test target? Don't worry, `:multi_scan` has fixed that. It will provide a separate test report for each test target. It can handle JUnit, HTML, JSON, and Apple's `test_result` bundles.

`test_result` bundles are particularly useful because they contain screenshots of the UI when a UI test fails so you can review what was actually there compared to what you expected.

<details>
    <summary>Example Code (expand to view):</summary>
<!-- multi_scan examples: begin -->

```ruby

UI.important(
  'example: ' \
  'run tests for a scheme that has two test targets, re-trying up to 2 times if ' \
  'tests fail. Turn off the default behavior of failing the build if, at the ' \
  'end of the action, there were 1 or more failing tests.'
)
summary = multi_scan(
  project: File.absolute_path('../AtomicBoy/AtomicBoy.xcodeproj'),
  scheme: 'AtomicBoy',
  try_count: 3,
  fail_build: false,
  output_files: 'report.html',
  output_types: 'html'
)
UI.success("multi_scan passed? #{summary[:result]}")

```

```ruby

UI.important(
  'example: ' \
  'split the tests into 2 batches and run each batch of tests up to 3 ' \
  'times if tests fail. Do not fail the build.'
)
multi_scan(
  project: File.absolute_path('../AtomicBoy/AtomicBoy.xcodeproj'),
  scheme: 'AtomicBoy',
  try_count: 3,
  batch_count: 2,
  fail_build: false
)

```

```ruby

UI.important(
  'example: ' \
  'split the tests into 2 batches and run each batch of tests up to 3 ' \
  'times if tests fail. Abort the testing early if there are too many ' \
  'failing tests by passing in a :testrun_completed_block that is called ' \
  'by :multi_scan after each run of tests.'
)
test_run_block = lambda do |testrun_info|
  failed_test_count = testrun_info[:failed].size
  passed_test_count = testrun_info[:passing].size
  try_attempt = testrun_info[:try_count]
  batch = testrun_info[:batch]

  # UI.abort_with_message!('You could conditionally abort')
  UI.message("\ὠA everything is fine, let's continue try #{try_attempt + 1} for batch #{batch}")
end

multi_scan(
  project: File.absolute_path('../AtomicBoy/AtomicBoy.xcodeproj'),
  scheme: 'AtomicBoy',
  try_count: 3,
  batch_count: 2,
  fail_build: false,
  testrun_completed_block: test_run_block
)

```

```ruby

UI.important(
  'example: ' \
  'use the :workspace parameter instead of the :project parameter to find, ' \
  'build, and test the iOS app.'
)
 multi_scan(
  workspace: File.absolute_path('../AtomicBoy/AtomicBoy.xcworkspace'),
  scheme: 'AtomicBoy',
  try_count: 3
)

```

```ruby

UI.important(
  'example: ' \
  'use the :workspace parameter instead of the :project parameter to find, ' \
  'build, and test the iOS app. Use the :skip_build parameter to not rebuild.'
)
multi_scan(
  workspace: File.absolute_path('../AtomicBoy/AtomicBoy.xcworkspace'),
  scheme: 'AtomicBoy',
  skip_build: true,
  clean: true,
  try_count: 3,
  result_bundle: true,
  fail_build: false
)

```

```ruby

UI.important(
  'example: ' \
  'multi_scan also works with just one test target in the Scheme.'
)
multi_scan(
  project: File.absolute_path('../AtomicBoy/AtomicBoy.xcodeproj'),
  scheme: 'Professor',
  try_count: 3,
  custom_report_file_name: 'atomic_report.xml',
  output_types: 'junit',
  fail_build: false
)

```

```ruby

UI.important(
  'example: ' \
  'multi_scan also can also run just the tests passed in the ' \
  ':only_testing option.'
)
multi_scan(
  workspace: File.absolute_path('../AtomicBoy/AtomicBoy.xcworkspace'),
  scheme: 'AtomicBoy',
  try_count: 3,
  only_testing: ['AtomicBoyTests'],
  fail_build: false
)

```

```ruby

UI.important(
  'example: ' \
  'multi_scan also works with json.'
)
multi_scan(
  workspace: File.absolute_path('../AtomicBoy/AtomicBoy.xcworkspace'),
  scheme: 'AtomicBoy',
  try_count: 3,
  output_types: 'json',
  output_files: 'report.json',
  fail_build: false
)

```
<!-- multi_scan examples: end -->
</details>

### suppress_tests_from_junit

Do you not have time to fix a test and it can be tested manually? You can suppress the `:failed` tests in your project and create and prioritize a ticket in your bug tracking system. 

Do you want to create a special CI job that only re-tries failing tests? Suppress the `:passing` tests in your project and exercise your fragile tests.

<details>
    <summary>Example Code (expand to view):</summary>
<!-- suppress_tests_from_junit examples: begin -->

```ruby

UI.important(
  'example: ' \
  'suppress the tests that failed in the junit report for _all_ Schemes'
)
suppress_tests_from_junit(
  xcodeproj: 'AtomicBoy/AtomicBoy.xcodeproj',
  junit: './spec/fixtures/junit.xml',
  suppress_type: :failed
)
UI.message(
  "Suppressed tests for project: #{suppressed_tests(xcodeproj: 'AtomicBoy/AtomicBoy.xcodeproj')}"
)

```

```ruby

UI.important(
  'example: ' \
  'suppress the tests that failed in the junit report for _one_ Scheme'
)
suppress_tests_from_junit(
  xcodeproj: 'AtomicBoy/AtomicBoy.xcodeproj',
  junit: './spec/fixtures/junit.xml',
  scheme: 'Professor',
  suppress_type: :failed
)
UI.message(
  "Suppressed tests for the 'Professor' scheme: #{suppressed_tests(xcodeproj: 'AtomicBoy/AtomicBoy.xcodeproj')}"
)

```
<!-- suppress_tests_from_junit examples: end -->
</details>

### suppress_tests

Have some tests that you want turned off? Give the list to this action in order to suppress them for your project.

<details>
    <summary>Example Code (expand to view):</summary>
<!-- suppress_tests examples: begin -->

```ruby

UI.important(
  'example: ' \
  'suppress some tests in all Schemes for a Project'
)
suppress_tests(
  xcodeproj: 'AtomicBoy/AtomicBoy.xcodeproj',
  tests: [
    'AtomicBoyUITests/HappyNapperTests/testBeepingNonExistentFriendDisplaysError',
    'AtomicBoyUITests/GrumpyWorkerTests'
  ]
)

```

```ruby

UI.important(
  'example: ' \
  'suppress some tests in one Scheme for a Project'
)
suppress_tests(
  xcodeproj: 'AtomicBoy/AtomicBoy.xcodeproj',
  tests: [
    'AtomicBoyUITests/HappyNapperTests/testBeepingNonExistentFriendDisplaysError',
    'AtomicBoyUITests/GrumpyWorkerTests'
  ],
  scheme: 'Professor'
)

```

```ruby

UI.important(
  'example: ' \
  'suppress some tests in one Scheme from a workspace'
)
suppress_tests(
  workspace: 'AtomicBoy/AtomicBoy.xcworkspace',
  tests: [
    'AtomicBoyUITests/HappyNapperTests/testBeepingNonExistentFriendDisplaysError',
    'AtomicBoyUITests/GrumpyWorkerTests'
  ],
  scheme: 'Professor'
)

```
<!-- suppress_tests examples: end -->
</details>

### suppressed_tests

Do you have an automated process that requires the list of suppressed tests in your project? Use this action to get that.

<details>
    <summary>Example Code (expand to view):</summary>
<!-- suppressed_tests examples: begin -->

```ruby

UI.important(
  'example: ' \
  'get the tests that are suppressed in a Scheme in the Project'
)
tests = suppressed_tests(
  xcodeproj: 'AtomicBoy/AtomicBoy.xcodeproj',
  scheme: 'AtomicBoy'
)
UI.message("Suppressed tests for scheme: #{tests}")

```

```ruby

UI.important(
  'example: ' \
  'get the tests that are suppressed in all Schemes in the Project'
)
UI.message(
  "Suppressed tests for project: #{suppressed_tests(xcodeproj: 'AtomicBoy/AtomicBoy.xcodeproj')}"
)

```

```ruby

UI.important(
  'example: ' \
  'get the tests that are suppressed in all Schemes in a workspace'
)
tests = suppressed_tests(
  workspace: File.absolute_path('../AtomicBoy/AtomicBoy.xcworkspace'),
  scheme: 'Professor'
)
UI.message("tests: #{tests}")

```
<!-- suppressed_tests examples: end -->
</details>

### tests_from_junit

Performing analysis on a test report file? Get the lists of failing and passing tests using this action.

<details>
    <summary>Example Code (expand to view):</summary>
<!-- tests_from_junit examples: begin -->

```ruby

UI.important(
  'example: ' \
  'get the failed and passing tests from the junit test report file'
)
result = tests_from_junit(junit: './spec/fixtures/junit.xml')
UI.message("Passing tests: #{result[:passing]}")
UI.message("Failed tests: #{result[:failed]}")

```
<!-- tests_from_junit examples: end -->
</details>

### tests_from_xctestrun

Do you have multiple test targets referenced by your `xctestrun` file and need to know all the tests? Use this action to go through each test target, collect the tests, and return them to you in a simple and usable structure.

<details>
    <summary>Example Code (expand to view):</summary>
<!-- tests_from_xctestrun examples: begin -->

```ruby

require 'fastlane/actions/scan'

UI.important(
  'example: ' \
  'get list of tests that are referenced from an xctestrun file'
)
# build the tests so that we have a xctestrun file to parse
scan(
  build_for_testing: true,
  workspace: File.absolute_path('../AtomicBoy/AtomicBoy.xcworkspace'),
  scheme: 'AtomicBoy'
)

# find the xctestrun file
derived_data_path = Scan.config[:derived_data_path]
xctestrun_file = Dir.glob("#{derived_data_path}/Build/Products/*.xctestrun").first

# get the tests from the xctestrun file
tests = tests_from_xctestrun(xctestrun: xctestrun_file)
UI.header('xctestrun file contains the following tests')
tests.values.flatten.each { |test_identifier| puts test_identifier }

```
<!-- tests_from_xctestrun examples: end -->
</details>

### collate_junit_reports

Do you have multiple junit test reports coming in from different sources and need it combined? Use this action to collate all the tests performed for a given test target into one report file.

<details>
    <summary>Example Code (expand to view):</summary>
<!-- collate_junit_reports examples: begin -->

```ruby

UI.important(
  'example: ' \
  'collate the xml reports to a temporary file "result.xml"'
)
reports = Dir['../spec/fixtures/*.xml'].map { |relpath| File.absolute_path(relpath) }
collate_junit_reports(
  reports: reports,
  collated_report: File.join(Dir.mktmpdir, 'result.xml')
)

```
<!-- collate_junit_reports examples: end -->
</details>

### collate_html_reports

Do you have multiple html test reports coming in from different sources and need it combined? Use this action to collate all the tests performed for a given test target into one report file.

<details>
    <summary>Example Code (expand to view):</summary>
<!-- collate_html_reports examples: begin -->

```ruby

UI.important(
  'example: ' \
  'collate the html reports to a temporary file "result.html"'
)
reports = Dir['../spec/fixtures/*.html'].map { |relpath| File.absolute_path(relpath) }
collate_html_reports(
  reports: reports,
  collated_report: File.join(Dir.mktmpdir, 'result.html')
)

```
<!-- collate_html_reports examples: end -->
</details>

### collate_json_reports

Do you have multiple json test reports coming in from different sources and need it combined? Use this action to collate all the tests performed for a given test target into one report file.

<details>
    <summary>Example Code (expand to view):</summary>
<!-- collate_json_reports examples: begin -->

```ruby

UI.important(
  'example: ' \
  'collate the json reports to a temporary file "result.json"'
)
reports = Dir['../spec/fixtures/report*.json'].map { |relpath| File.absolute_path(relpath) }
collate_json_reports(
  reports: reports,
  collated_report: File.join(Dir.mktmpdir, 'result.json')
)

```
<!-- collate_json_reports examples: end -->
</details>

### collate_test_result_bundles

Do you have multiple test_result bundles coming in from different sources and need it combined? Use this action to collate all the tests performed for a given test target into one test_result bundle.

<details>
    <summary>Example Code (expand to view):</summary>
<!-- collate_test_result_bundles examples: begin -->

```ruby

UI.important(
  'example: ' \
  'collate the test_result bundles to a temporary bundle "result.test_result"'
)
bundles = Dir['../spec/fixtures/*.test_result'].map { |relpath| File.absolute_path(relpath) }
collate_test_result_bundles(
  bundles: bundles,
  collated_bundle: File.join(Dir.mktmpdir, 'result.test_result')
)

```
<!-- collate_test_result_bundles examples: end -->
</details>

## Run tests for this plugin

To run both the tests, and code style validation, run

```
rake
```

To automatically fix many of the styling issues, use
```
rubocop -a
```

## Issues and Feedback

For any other issues and feedback about this plugin, please [submit it](https://github.com/lyndsey-ferguson/fastlane-plugin-test_center/issues) to this repository.

## Contributing

If you would like to contribute to this plugin, please review the [contributing document][contributing doc].

## Troubleshooting

If you have trouble using plugins, check out the [Plugins Troubleshooting](https://docs.fastlane.tools/plugins/plugins-troubleshooting/) guide.

## Using _fastlane_ Plugins

For more information about how the `fastlane` plugin system works, check out the [Plugins documentation](https://docs.fastlane.tools/plugins/create-plugin/).

## About _fastlane_

_fastlane_ is the easiest way to automate beta deployments and releases for your iOS and Android apps. To learn more, check out [fastlane.tools](https://fastlane.tools).

## License

MIT

<!-- Links -->
[contributing doc]: ./docs/CONTRIBUTING.md
