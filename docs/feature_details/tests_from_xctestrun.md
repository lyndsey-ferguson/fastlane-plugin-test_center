
# ☑️  tests_from_xctestrun

Do you have multiple test targets referenced by your `xctestrun` file and need to know all the tests? Use this action to go through each test target, collect the tests, and return them to you in a simple and usable structure.

<center><img src="./images/xcrun_tests.png" alt="tests from xctestrun" /></center>

## Example

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

## Parameters

<!-- tests_from_xctestrun parameters: begin -->
|Parameter|Description|Default Value|
|:-|:-|-:|
|xctestrun|The xctestrun file to use to find where the xctest bundle file is for test retrieval||
|invocation_based_tests|Set to true If your test suit have invocation based tests like Kiwi|false|
<!-- tests_from_xctestrun parameters: end -->
