

# ☑️  test_options_from_testplan

Get the tests and test coverage values from a given testplan.

## Example

<!-- test_options_from_testplan examples: begin -->

```ruby

UI.important(
  'example: ' \
  'get the tests and the test coverage configuration from a given testplan'
)
test_options = test_options_from_testplan(
  testplan: 'AtomicBoy/AtomicBoy_2.xctestplan'
)
UI.message("The AtomicBoy_2 testplan has the following tests: #{test_options[:only_testing'}")

```
<!-- test_options_from_testplan examples: end -->

## Parameters

<!-- test_options_from_testplan parameters: begin -->
|Parameter|Description|Default Value|
|:-|:-|-:|
|testplan|The Xcode testplan to read the test info from||
<!-- test_options_from_testplan parameters: end -->
