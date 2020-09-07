
# 🔸 collate_test_result_bundles

Do you have multiple test_result bundles coming in from different sources and need them combined? Use this action to collate all the tests performed for a given test target into one test_result bundle.

## Example

<!-- collate_test_result_bundles examples: begin -->

```ruby

UI.important(
  'example: ' \
  'collate the test_result bundles to a temporary bundle "result.test_result"'
)
bundles = Dir['../spec/fixtures/*.test_result'].map { |relpath| File.absolute_path(relpath) }
Dir.mktmpdir('test_output') do |dir|
  collate_test_result_bundles(
    bundles: bundles,
    collated_bundle: File.join(dir, 'result.test_result')
  )
end

```
<!-- collate_test_result_bundles examples: end -->

## Parameters

<!-- collate_test_result_bundles parameters: begin -->
|Parameter|Description|Default Value|
|:-|:-|-:|
|bundles|An array of test_result bundles to collate. The first bundle is used as the base into which other bundles are merged in||
|collated_bundle|The final test_result bundle where all testcases will be merged into|result.test_result|
<!-- collate_test_result_bundles parameters: end -->
