# Testing _test_center_

## Testing your local changes

### Checking it all

The `Fastfile` included at the top `fastlane` directory of the test_center project allows you to run all the examples for each included action.

```
bundle exec fastlane run_examples
```

### Automated tests

Make sure to run the automated tests using `bundle exec` to ensure you’re running the correct version of `rspec` and `rubocop`

#### All unit and code style tests

First, navigate into the root of the _test_center_ project and run all unit and code style tests using

```
bundle exec rake
```

#### Specific unit test (group) in a specific test file

If you know the specific unit test or unit test group you want to run, use

```
bundle exec rspec ./fastlane/spec/fastlane_require_spec.rb:17
```

The number is the line number of the unit test (`it ... do`) or unit test group (`describe ... do`) you want to run.

Instead of using the line number you can also use a filter with the `it "something", now: true` notation and then use `bundle exec rspec -t now` to run this tagged test. (Note that `now` can be any random string of your choice.)
