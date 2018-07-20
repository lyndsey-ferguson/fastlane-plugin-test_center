# Your first PR

## Prerequisites

Before you start working on _test_center_, make sure you had a look at [CONTRIBUTING.md](CONTRIBUTING.md).

For working on _test_center_ you should have [Bundler][bundler] installed. Bundler is a ruby project that allows you to specify all ruby dependencies in a file called the `Gemfile`. If you want to learn more about how Bundler works, check out [their website][bundler help].

## Finding things to work on

Issues that are ready to be worked on and easily accessible for new contributors are usually tagged with the ["good first issue" label][good_first_issue]. If you’ve never contributed to a ruby project before, these are a great place to start!

If you want to work on something else, e.g. new functionality or fixing a bug, it would be helpful if you submit a new issue, so that we can have a chance to discuss it first. This is an opportunity to provide some pointers for you on how to get started, or how to best integrate it with existing solutions.

## Checking out the _test_center_ repo

- Click the “Fork” button in the upper right corner of the [main _test_center_ repo][fastlane-plug-test_center repo]
- Clone your fork:
  - `git clone git@github.com:<YOUR_GITHUB_USER>/fastlane-plugin-test_center.git`
  - Learn more about how to manage your fork: https://help.github.com/articles/working-with-forks/
- Install dependencies:
  - Run `bundle install` in the project root
  - If there are dependency errors, you might also need to run `bundle update`
- Create a new branch to work on:
  - `git checkout -b <YOUR_BRANCH_NAME>`
  - A good name for a branch describes the thing you’ll be working on, e.g. `issue-98-docs-fixes`, `issue-99-add-titanium-gridlock-suspension-manipulator`, etc.
- That’s it! Now you’re ready to work on _test_center_

## Testing your changes

[Testing _test_center_](Testing.md) is so important, that the instructions have their own documentation file. Each code change _must_ have a corresponding test.

## Submitting the PR

When the coding is done and you’re finished testing your changes, you are ready to submit the PR to the [_test_center_ main repo][fastlane-plug-test_center repo]. Everything you need to know about submitting the PR itself is inside our [Pull Request Template][pr template]. Some best practices are:

- Use a descriptive title
- Link the issues that are related to your PR in the body

## After the review

Once your PR has been reviewed, you might need to make changes before it gets merged. To make it easier, please make sure to avoid using `git commit --amend` or force pushes to make corrections. By avoiding rewriting the commit history, you will allow each round of edits to become its own visible commit. This helps the people who need to review your code easily understand exactly what has changed since the last time they looked. Feel free to use whatever commit messages you like, as we will squash them anyway. When you are done addressing your review, also add a small comment like “Feedback addressed @<your_reviewer>”.

_test_center_ does change. It can happen that after a review, your code might not work with the latest master branch anymore. To prevent this, before you make any changes after your code has been reviewed, you should always rebase the latest changes from the master branch.

After your contribution is merged, it’s not immediately available to all users. Your change will be shipped as part of the next release, which is usually once every two weeks. If your change is time critical, please make that clear know so we can schedule a release for your change.

<!-- Links -->
[good_first_issue]: https://github.com/lyndsey-ferguson/fastlane-plugin-test_center/issues?utf8=✓&q=is%3Aopen+is%3Aissue+label%3A%22good+first+issue%22+
[fastlane-plug-test_center repo]: https://github.com/lyndsey-ferguson/fastlane-plugin-test_center
[pr template]: ../.github/PULL_REQUEST_TEMPLATE.md
[bundler]: https://bundler.io
[bundler help]: https://bundler.io/v1.12/#getting-started