# test_center plugin

[![fastlane Plugin Badge](https://rawcdn.githack.com/fastlane/fastlane/master/fastlane/assets/plugin-badge.svg)](https://rubygems.org/gems/fastlane-plugin-test_center)

## Getting Started

This project is a [_fastlane_](https://github.com/fastlane/fastlane) plugin. To get started with `fastlane-plugin-test_center`, add it to your project by running:

```bash
fastlane add_plugin test_center
```

## About test_center

This plugin makes testing your iOS app easier by providing you actions that allow
you to run the fastlane `scan` action multiple times and retrying only failed
tests, retrieve which tests failed during `scan`, and suppressing given tests in
an Xcode project.

This fastlane plugin includes the following actions:
- `multi_scan`: uses scan to run Xcode tests a given number of times: only re-testing failing tests
- `suppress_tests_from_junit`: uses a junit xml report file to suppress either passing or failing tests in an Xcode Scheme
- `suppress_tests`: suppresses specific tests in a specific or all Xcode Schemes in a given project
- `suppressed_tests`: retrieves a list of tests that are suppressed in a specific or all Xcode Schemes in a project
- `tests_from_junit`: retrieves the failing and passing tests as reported in a junit xml file
- `collate_junit_reports`: collects and correctly organizes junit reports from multiple test passes

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
