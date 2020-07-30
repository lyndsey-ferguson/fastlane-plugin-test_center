

# ☑️  tests_from_xcresult

Performing analysis on an `.xcresult` bundle? Get the failing and passing tests using this action.

> **Note**: I'm making this new action available to Supporters first to show them appreciation. I'll open it up to everyone else on September 1st, 2020.
>
> Interested in joining? Click [here ♥️](https://github.com/sponsors/lyndsey-ferguson) and select a tier that gives you early access to new features.
>
> **Bonus**: if your organization (👨‍👩‍👧‍) becomes a Sponsor, every member of that org gets that same early access!

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
