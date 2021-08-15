

# ☑️  tests_from_xcresult

Performing analysis on an `.xcresult` bundle? Use this action to get a Hash of two arrays:
1. An array of `:passing` test identiers.
2. An array of `:failed` test identifers.

A test identifer is the full name of the test that ran `testSuite/testClass/testMethod`.


## Example

<!-- tests_from_xcresult examples: begin -->

```ruby

UI.important(
  'example: ' \
  'get the failed and passing tests from a xcresult bundle'
)
result = tests_from_xcresult(xcresult: './spec/fixtures/AtomicBoy.xcresult')
UI.message("Passing tests: #{result[:passing]}")
UI.message("Failed tests: #{result[:failed]}")

```
<!-- tests_from_xcresult examples: end -->

## Parameters

<!-- tests_from_xcresult parameters: begin -->
|Parameter|Description|Default Value|
|:-|:-|-:|
|xcresult|The path to the xcresult bundle to retrieve the tests from||
<!-- tests_from_xcresult parameters: end -->
