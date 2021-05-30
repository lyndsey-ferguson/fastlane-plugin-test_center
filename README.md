

<img src="docs/test_center_banner.png" />

# test_center plugin 🎯
[![fastlane Plugin Badge](https://rawcdn.githack.com/fastlane/fastlane/master/fastlane/assets/plugin-badge.svg)](https://rubygems.org/gems/fastlane-plugin-test_center) [![Actions Status](https://github.com/lyndsey-ferguson/fastlane-plugin-test_center/workflows/Run%20Tests/badge.svg)](https://github.com/lyndsey-ferguson/fastlane-plugin-test_center/actions)

Have you ever spent too much time trying to fix fragile tests only to give up with nothing real to show? Use the `fastlane` actions from `test_center` to remove the pain around your tests, so that you can focus on what makes 💰: features that customers love 😍.

> For those of you new to fastlane, I recommend that you read my article [Rescue Your Mobile Builds from Madness Using Fastlane](https://medium.com/appian-engineering/rescue-your-mobile-builds-from-madness-using-fastlane-cf123622f2d3).

<p align="center">
  <a href="#features">Features</a> |
  <a href="#installation">Installation</a> |
  <a href="#usage">Usage</a> |
  <a href="#issues-and-feedback">Issues &amp; Feedback</a> |
  <a href="#contributing">Contributing</a> |
  <a href="#troubleshooting">Troubleshooting</a> |
  <a href="#license">License</a>
</p>

<img src="docs/multi_scan.gif" />

## Features

This plugin makes testing your iOS app easier by providing you actions that give you greater control over everything related to testing your app.

`multi_scan` began when I created an action to only re-run the failed tests in order to determine if they were truly failing, or if they were failing randomly due to a fragile infrastructure. This action morphed into an entire plugin with many actions in the testing category.

This fastlane plugin includes the following actions:

_read the documentation on each action by clicking on the action name_

| Action | Description | Supported Platforms |
| :--- | :--- | ---: |
|[`multi_scan`](docs/feature_details/multi_scan.md)| supports everthing that [`scan`](https://docs.fastlane.tools/actions/scan/) (also known as `run_tests`) does, and also supports:</br></br>- dividing your tests evenly into batches and run each batch on its own Simulator in parallel to reduce the time to test</br>- re-running tests that may be failing due to a fragile test environment</br>- splitting tests into batches when a huge number of tests overwhelm the Simulator</br> - performing an action after a block of tests have been run| ios, mac |
| [`suppress_tests_from_junit`](docs/feature_details/suppress_tests_from_junit.md) | suppress tests in an Xcode Scheme using those in a Junit test report | ios, mac |
| [`suppress_tests`](docs/feature_details/suppress_tests.md) | suppress tests in an Xcode Scheme | ios, mac |
| [`suppressed_tests`](docs/feature_details/suppressed_tests.md) | returns a list of the suppressed tests in your Xcode Project or Scheme | ios, mac |
| [`test_options_from_testplan`](docs/feature_details/test_options_from_testplan.md) | returns the tests and test code coverage configuration for a given testplan | ios, mac |
| [`testplans_from_scheme`](docs/feature_details/testplans_from_scheme.md) | returns the testplans that an Xcode Scheme references | ios, mac |
| [`tests_from_junit`](docs/feature_details/tests_from_junit.md) | returns the passing and failing tests in a Junit test report | ios, mac |
| [`tests_from_xcresult`](docs/feature_details/tests_from_xcresult.md) | returns the passing and failing tests in a xcresult bundle | ios, mac |
| [`tests_from_xctestrun`](docs/feature_details/tests_from_xctestrun.md) | returns a list of tests for each test target in a `xctestrun` file  | ios, mac |
| [`collate_junit_reports`](docs/feature_details/collate_junit_reports.md) | combines multiple Junit test reports into one report | ios, mac |
| [`collate_html_reports`](docs/feature_details/collate_html_reports.md) | combines multiple HTML test reports into one report | ios, mac |
| [`collate_json_reports`](docs/feature_details/collate_json_reports.md) | combines multiple json test reports into one report | ios, mac |
| [`collate_test_result_bundles`](docs/feature_details/collate_test_result_bundles.md) | combines multiple test_result bundles into one test_result bundle | ios, mac |
| [`collate_xcresults`](docs/feature_details/collate_xcresults.md) | combines multiple xcresult bundles into one xcresult bundle | ios, mac |


## Installation

This project is a [_fastlane_](https://github.com/fastlane/fastlane) plugin. To get started with `fastlane-plugin-test_center`, add it to your project by running:

```bash
fastlane add_plugin test_center
```

## Usage

Click the name of each action [above](#features) and review the documentation to learn how to use each action.

The most popular action in the `test_center` plugin is `multi_scan`, and if you run your tests in parallel with multiple retries, they will finish faster and only the truly failing tests will be reported as failing:

```action
multi_scan(
  project: File.absolute_path('../AtomicBoy/AtomicBoy.xcodeproj'),
  scheme: 'AtomicBoy',
  try_count: 3, # retry _failing_ tests up to three times^1.
  fail_build: false,
  parallel_testrun_count: 4 # run subsets of your tests on parallel simulators^2
)
# [1] The ones that pass on a retry probably failed due to test interactions or test infrastructure
# [2] splits all your tests into 4 smaller batches and runs each batch on its own sim in parallel for faster completion!
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

## Supporters

![Владислав Давыдов](https://avatars1.githubusercontent.com/u/47553334?s=44&u=4691860dba898943b947180b3d28bb85851b0d7c&v=4)
[vdavydovHH](https://github.com/vdavydovHH)  
## License

MIT

<!-- Links -->
[contributing doc]: ./docs/CONTRIBUTING.md
