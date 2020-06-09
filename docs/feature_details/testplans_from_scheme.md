

# ☑️  testplans_from_scheme

Get the testplans that an Xcode Scheme references.

## Example

<!-- testplans_from_scheme examples: begin -->

```ruby

UI.important(
  'example: ' \
  'get all the testplans that an Xcode Scheme references'
)
testplans = testplans_from_scheme(
  xcodeproj: 'AtomicBoy/AtomicBoy.xcodeproj',
  scheme: 'AtomicBoy'
)
UI.message("The AtomicBoy uses the following testplans: #{testplans}")

```
<!-- testplans_from_scheme examples: end -->

## Parameters

<!-- testplans_from_scheme parameters: begin -->
|Parameter|Description|Default Value|
|:-|:-|-:|
|xcodeproj|The file path to the Xcode project file that references the Scheme||
|workspace|The file path to the Xcode workspace file that references the Scheme||
|scheme|The Xcode scheme referencing the testplan||
<!-- testplans_from_scheme parameters: end -->
