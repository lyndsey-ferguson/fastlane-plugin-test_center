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
- [`multi_scan`](#multi-scan): gives you control over how your tests are exercised.
- [`suppress_tests_from_junit`](#suppress_tests_from_junit): from a test report, suppresses tests in your project.
- [`suppress_tests`](#suppress_tests): from a provided list, suppresses tests in your project.
- [`suppressed_tests`](#suppressed_tests): returns a list of the suppressed tests in your project.
- [`tests_from_junit`](#tests_from_junit): from a test report, returns lists of passing and failed tests.
- [`tests_from_xctestrun`](#tests_from_xctestrun): from an xctestrun file, returns a list of tests for each of its test targets.
- [`collate_junit_reports`](#collate_junit_reports): combines multiple junit test reports into one report.
- [`collate_html_reports`](#collate_html_reports): combines multiple html test reports into one report.

### multi-scan 🎉

Is the fragile test infrastructure provided by `xcodebuild` failing tests inexplicably and getting you down 😢? Use the `:try_count` option to re-run those failed tests multiple times to ensure that any fragility is ironed out and only truly failing tests appear.

Is the sheer number of UI tests overloading the iOS Simulator and causing it to become useless? Run your tests in batches using the `:batch_count` option in order to lighten the load on the simulator.

Do you get frustrated when your automated test system keeps running after the fragile test infrastructure stops working halfway through your tests 😡? Use the `:testrun_completed_block` callback to bailout early or make adjustments on how your tests are exercised.

Do you have multiple test targets and the normal operation of `scan` is providing you a test report that implies that all the tests ran in one test target? Don't worry, `multi_scan` has fixed that.

### suppress_tests_from_junit

No time to fix a failing test? Suppress the `:failed` tests in your project and create and prioritize a ticket in your bug tracking system. 

Want to create a special CI job that only re-tries failing tests? Suppress the `:passing` tests in your project and exercise your fragile tests.

### suppress_tests

Have some tests that you want turned off? Give the list to this action in order to suppress them for your project.

### suppressed_tests

Do you have an automated process that requires the list of suppressed tests in your project? Use this action to get that.

### tests_from_junit

Performing analysis on a test report file? Get the lists of failing and passing tests using this action.

### tests_from_xctestrun

Do you have multiple test targets referenced by your `xctestrun` file and need to know all the tests? Use this action to go through each test target, collect the tests, and return them to you in a simple and usable structure.

### collate_junit_reports

Do you have multiple junit test reports coming in from different sources and need it combined? Use this action to collate all the tests performed for a given test target into one report file.

### collate_html_reports

Do you have multiple html test reports coming in from different sources and need it combined? Use this action to collate all the tests performed for a given test target into one report file.

## Example

Check out the [example `Fastfile`](fastlane/Fastfile) to see how to use this plugin. Try it by cloning the repo, running `fastlane install_plugins` and `bundle exec fastlane test`.

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
