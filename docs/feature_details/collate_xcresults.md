
# 🔸 collate_xcresults

Do you have multiple xcresult bundles coming in from different sources and need them combined? Use this action to collate all the tests performed for a given test target into one xcresult bundle.

## Example

<!-- collate_xcresults examples: begin -->

```ruby

UI.important(
  'example: ' \
  'collate the xcresult bundles to a temporary xcresult bundle "result.xcresult"'
)
xcresults = Dir['../spec/fixtures/*.xcresult'].map { |relpath| File.absolute_path(relpath) }
collate_xcresults(
  xcresults: xcresults,
  collated_xcresult: File.join('test_output', 'result.xcresult')
)

```
<!-- collate_xcresults examples: end -->

## Parameters

<!-- collate_xcresults parameters: begin -->
|Parameter|Description|Default Value|
|:-|:-|-:|
|xcresults|An array of xcresult bundles to collate||
|collated_xcresult|The merged xcresult bundle|result.xcresult|
<!-- collate_xcresults parameters: end -->
