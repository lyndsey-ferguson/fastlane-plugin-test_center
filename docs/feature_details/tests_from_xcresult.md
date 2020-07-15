

# ☑️  tests_from_xcresult

Performing analysis on an `.xcresult` bundle? Get the failing and passing tests using this action.

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
