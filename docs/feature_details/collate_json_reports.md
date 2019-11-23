
# 🔹 collate_json_reports

Do you have multiple json test reports coming in from different sources and need them combined? Use this action to collate all the tests performed for a given test target into one report file.

## Example

<!-- collate_json_reports examples: begin -->

```ruby

UI.important(
  'example: ' \
  'collate the json reports to a temporary file "result.json"'
)
reports = Dir['../spec/fixtures/report*.json'].map { |relpath| File.absolute_path(relpath) }
collate_json_reports(
  reports: reports,
  collated_report: File.join(Dir.mktmpdir, 'result.json')
)

```
<!-- collate_json_reports examples: end -->
## Parameters

<!-- collate_json_reports parameters: begin -->
|Parameter|Description|Default Value|
|:-|:-|-:|
|reports|An array of JSON reports to collate. The first report is used as the base into which other reports are merged in||
|collated_report|The final JSON report file where all testcases will be merged into|result.json|
<!-- collate_json_reports parameters: end -->
