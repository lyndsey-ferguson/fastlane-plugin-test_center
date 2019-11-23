
# 🗜 suppress_tests

Have some tests that you want turned off? Give the list of the tests to this action in order to suppress them for your Xcode Project or Scheme.

## Examples

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

## Parameters

<!-- suppress_tests parameters: begin -->
|Parameter|Description|Default Value|
|:-|:-|-:|
|xcodeproj|The file path to the Xcode project file to modify||
|workspace|The file path to the Xcode workspace file to modify||
|tests|A list of tests to suppress||
|scheme|The Xcode scheme where the tests should be suppressed||
<!-- suppress_tests parameters: end -->
