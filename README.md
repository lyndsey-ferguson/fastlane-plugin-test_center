# test_center plugin 🎯

[![fastlane Plugin Badge](https://rawcdn.githack.com/fastlane/fastlane/master/fastlane/assets/plugin-badge.svg)](https://rubygems.org/gems/fastlane-plugin-test_center)

## Getting Started

This project is a [_fastlane_](https://github.com/fastlane/fastlane) plugin. To get started with `fastlane-plugin-test_center`, add it to your project by running:

```bash
fastlane add_plugin test_center
```

## About test_center

This plugin makes testing your iOS app easier by providing you actions that give you greater control over everthing related to testing your app. 

The `test_center` plugin started with a problem when working on automated iOS tests:

```
😘 - code is done, time to run the automated tests

✅✅✅✅✅❌❌✅❌✅✅❌❌✅✅✅✅✅❌✅✅✅✅✅✅✅✅❌✅✅✅✅❌❌✅✅❌❌❌✅✅✅✅✅✅❌✅✅

🤓 - most of these tests run fine locally and I do not know how to fix them...

😕 - bummer, maybe if I re-run the tests?

✅✅✅✅✅❌✅✅✅❌✅❌✅✅✅❌✅✅✅❌❌✅✅✅✅✅✅✅✅❌❌✅✅❌✅✅✅❌✅✅✅✅❌✅✅✅✅✅

☹️ - aw man, still failing? One more time? 🤞

✅✅✅✅❌❌✅✅✅✅✅✅✅✅✅✅✅❌✅✅❌✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅❌✅✅✅✅✅✅❌✅✅✅

😡 - this is terrible, my tests keep failing randomly!

🤔 - maybe there is a better way?

🕐 🕡 🕚

> enter multi_scan

😘 - code is done, time to run the automated tests

✅✅✅✅✅❌✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅❌✅✅✅✅✅✅✅✅✅✅

😕 - bummer, maybe if I re-run multi_scan again?

✅✅✅✅✅❌✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅❌✅✅✅✅✅✅✅✅✅✅

😕 - hmmm, maybe these are real test failures?

✅✅✅✅✅❌✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅❌✅✅✅✅✅✅✅✅✅✅

😛 - okay, these are real test failures, time to fix them!

✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅

😍 - green is joy!
```

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

### multi_scan 🎉

Is the fragile test infrastructure provided by `xcodebuild` failing tests inexplicably and getting you down 😢? Use the `:try_count` option to re-run those failed tests multiple times to ensure that any fragility is ironed out and only truly failing tests appear.

Is the sheer number of UI tests overloading the iOS Simulator and causing it to become useless? Run your tests in batches using the `:batch_count` option in order to lighten the load on the simulator.

Do you get frustrated when your automated test system keeps running after the fragile test infrastructure stops working halfway through your tests 😡? Use the `:testrun_completed_block` callback to bailout early or make adjustments on how your tests are exercised.

Do you have multiple test targets and the normal operation of `scan` is providing you a test report that implies that all the tests ran in one test target? Don't worry, `multi_scan` has fixed that.

<details>
    <summary>Example Code:</summary>
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
  'run tests for a scheme that has two test targets, re-trying up to 2 times if ' \
  'tests fail. Make sure that the default behavior of failing the build works.'
)
begin
  multi_scan(
    project: File.absolute_path('../AtomicBoy/AtomicBoy.xcodeproj'),
    scheme: 'AtomicBoy',
    try_count: 2
  )
rescue FastlaneCore::Interface::FastlaneTestFailure => e
  UI.success("failed successfully with #{e.message}")
else
  raise 'This should have failed'
end

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

  if passed_test_count > 0 && failed_test_count > passed_test_count / 2
    UI.abort_with_message!("Too many tests are failing")
  end
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
  result_bundle: true
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
  output_types: 'junit,html',
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
  only_testing: ['AtomicBoyTests']
)

```
<!-- multi_scan examples: end -->
</details>

### suppress_tests_from_junit

No time to fix a failing test? Suppress the `:failed` tests in your project and create and prioritize a ticket in your bug tracking system. 

Want to create a special CI job that only re-tries failing tests? Suppress the `:passing` tests in your project and exercise your fragile tests.

<details>
    <summary>Example Code:</summary>
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
    <summary>Example Code:</summary>
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
<!-- suppress_tests examples: end -->
</details>

### suppressed_tests

Do you have an automated process that requires the list of suppressed tests in your project? Use this action to get that.

<details>
    <summary>Example Code:</summary>
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
<!-- suppressed_tests examples: end -->
</details>

### tests_from_junit

Performing analysis on a test report file? Get the lists of failing and passing tests using this action.

<details>
    <summary>Example Code:</summary>
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
    <summary>Example Code:</summary>
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
    <summary>Example Code:</summary>
<!-- collate_junit_reports examples: begin -->

```ruby

UI.important(
  'example: ' \
  'collate the xml reports to a temporary file 'result.xml''
)
collate_junit_reports(
  reports: Dir['./spec/fixtures/*.xml'],
  collated_report: File.join(Dir.mktmpdir, 'result.xml')
)

```
<!-- collate_junit_reports examples: end -->
</details>

### collate_html_reports

Do you have multiple html test reports coming in from different sources and need it combined? Use this action to collate all the tests performed for a given test target into one report file.

<details>
    <summary>Example Code:</summary>
<!-- collate_html_reports examples: begin -->

```ruby

UI.important(
  'example: ' \
  'collate the html reports to a temporary file 'result.html''
)
collate_html_reports(
  reports: Dir['./spec/fixtures/*.html'],
  collated_report: File.join(Dir.mktmpdir, 'result.html')
)

```
<!-- collate_html_reports examples: end -->
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

For any other issues and feedback about this plugin, please submit it to this repository.

## Troubleshooting

If you have trouble using plugins, check out the [Plugins Troubleshooting](https://docs.fastlane.tools/plugins/plugins-troubleshooting/) guide.

## Using _fastlane_ Plugins

For more information about how the `fastlane` plugin system works, check out the [Plugins documentation](https://docs.fastlane.tools/plugins/create-plugin/).

## About _fastlane_

_fastlane_ is the easiest way to automate beta deployments and releases for your iOS and Android apps. To learn more, check out [fastlane.tools](https://fastlane.tools).
