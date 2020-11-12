
# 🔷 collate_junit_reports

Do you have multiple junit test reports coming in from different sources and need them combined? Use this action to collate all the tests performed for a given test target into one report file.

> Note: if you want to use `--verbose` to get more detailed logging, but you don't want to see the detailed logging for `collate_junit_reports`, set the environment variable `COLLATE_JUNIT_REPORTS_VERBOSITY` to 0.

## Example

<!-- collate_junit_reports examples: begin -->

```ruby

UI.important(
  'example: ' \
  'collate the xml reports to a temporary file "result.xml"'
)
reports = Dir['../spec/fixtures/*.xml'].map { |relpath| File.absolute_path(relpath) }
collate_junit_reports(
  reports: reports.sort_by { |f| File.mtime(f) },
  collated_report: File.join(Dir.mktmpdir, 'result.xml')
)

```
<!-- collate_junit_reports examples: end -->

## Parameters

<!-- collate_junit_reports parameters: begin -->
|Parameter|Description|Default Value|
|:-|:-|-:|
|reports|An array of junit reports to collate. The first report is used as the base into which other reports are merged in||
|collated_report|The final junit report file where all testcases will be merged into|result.xml|
<!-- collate_junit_reports parameters: end -->
