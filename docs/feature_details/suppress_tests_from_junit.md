
# 🗜 suppress_tests_from_junit

Do you not have time to fix a test and it can be tested manually? You can suppress the `:failed` tests in your project and create and prioritize a ticket in your bug tracking system. 

Do you want to create a special CI job that only re-tries failing tests? Suppress the `:passing` tests in your project and exercise your fragile tests.

## Examples

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

## Parameters

<!-- suppress_tests_from_junit parameters: begin -->
|Parameter|Description|Default Value|
|:-|:-|-:|
|xcodeproj|The file path to the Xcode project file to modify||
|junit|The junit xml report file from which to collect the tests to suppress||
|scheme|The Xcode scheme where the tests should be suppressed||
|suppress_type|Tests to suppress are either :failed or :passing||
<!-- suppress_tests_from_junit parameters: end -->
