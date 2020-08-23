require 'bundler/gem_tasks'
require 'colorize'
require 'rspec/core/rake_task'
require_relative 'fastlane/test_center_utils'
require 'fastlane'
require 'markdown-tables'
require 'yaml'

RSpec::Core::RakeTask.new

require 'rubocop/rake_task'
RuboCop::RakeTask.new(:rubocop)

GEMS_BLACKLISTED_FROM_RELEASE = [
  'pry-byebug'
]

desc 'Ensures that no blacklisted require "x" exist in the code'
task :check_for_blacklisted_requires do
  errors = []
  gem_blacklist_regex = "('|\")(?<blacklisted_gem>#{GEMS_BLACKLISTED_FROM_RELEASE.join('|')})('|\")"

  Dir["lib/**/*.rb"].each do |file|
    File.foreach(file) do |line|
      if (m = /\s*require\s+#{gem_blacklist_regex}/.match(line))
        errors << "require '#{m[:blacklisted_gem]}' found in '#{file}'"
      end
    end
  end
  unless errors.empty?
    errors.each { |line| puts line }
    abort 'Error: blacklisted require(s) found'.red
  end
  puts 'No blacklisted requires found'.green
end


def update_examples_block(action, examples, file)
  file.puts("<!-- #{action} examples: begin -->")
  examples.each do |example_code_snippet|
    file.puts('')
    file.puts('```ruby')
    example_code_snippet.lines do |example_code_snippet_line|
      file.puts(example_code_snippet_line.sub('          ', ''))
    end
    file.puts('```')
  end
  file.puts("<!-- #{action} examples: end -->")
end

def update_parameters_block(action, options, file)
  file.puts("<!-- #{action} parameters: begin -->")
  rows = []
  options.each do |option|
    rows << option.values
  end
  labels = ['Parameter', 'Description', 'Default Value']
  file.puts(MarkdownTables.make_table(labels, rows, is_rows: true, align: ['l', 'l', 'r']))
  file.puts("<!-- #{action} parameters: end -->")
end

desc 'Updates the docs for each action with the latest examples'
task :update_action_doc_examples do
  examples, available_options = action_info

  examples.keys.each do |action_name|
    action_filepath = File.join('docs', 'feature_details', "#{action_name}.md")
    action_file = File.read(action_filepath)
    parsing_state = :transfer
    File.open(action_filepath, 'w') do |file|
      action_file.lines do |line|
        case line
        when /<!-- (?<#{action_name}>\w+) examples: (begin|end) -->/
          parsing_state = :entered_examples_block if /.+begin -->/ =~ line
          parsing_state = :exited_examples_block if /.+end -->/ =~ line
        when /<!-- (?<#{action_name}>\w+) parameters: (begin|end) -->/
          parsing_state = :entered_parameters_block if /.+begin -->/ =~ line
          parsing_state = :exited_parameters_block if /.+end -->/ =~ line
        end

        case parsing_state
        when :transfer
          file.puts line
        when :exited_examples_block
          update_examples_block(action_name, examples[action_name], file)
          parsing_state = :transfer
        when :exited_parameters_block
          update_parameters_block(action_name, available_options[action_name], file)
          parsing_state = :transfer
        end
      end
    end
  end
end

GITHUB_WORKFLOW_FILEPATH = '.github/workflows/main.yml'

def github_job_definition(lane_name)
  job_definition = """
    if: contains(github.event.pull_request.labels.*.name, 'run tests')
    name: #{lane_name}
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v1
      - name: setup
        run: |
          gem install bundler
          bundle install
      - name: run #{lane_name}
        run: bundle exec fastlane #{lane_name}
  """
  YAML.load(job_definition)
end

def update_github_workflow_standard_jobs(workflow)
  standard_jobs = """
    test_on_older_rubies:
      runs-on: macos-latest
      strategy:
        matrix:
          ruby:
          - 2.4.x
          - 2.5.x
      name: Run Tests with Ruby ${{ matrix.ruby }}
      steps:
      - uses: actions/checkout@v1
      - uses: actions/setup-ruby@v1
        with:
          ruby-version: \"${{ matrix.ruby }}\"
      - name: setup
        run: |
          gem install bundler
          bundle install
      - name: lint
        run: bundle exec rubocop
      - name: test
        run: bundle exec rspec
    test_on_latest_ruby:
      name: Run Tests with the latest Ruby
      runs-on: macos-latest
      steps:
      - uses: actions/checkout@v1
      - name: setup
        run: |
          gem install bundler
          bundle install
      - name: lint
        run: bundle exec rubocop
      - name: test
        run: bundle exec rspec
  """
  workflow['jobs'] = YAML.load(standard_jobs)
end


desc 'Builds the CI jobs based on the examples and tests from each action'
task :update_action_ci_jobs do
  action_examples, _, action_integration_tests = action_info
  workflow = YAML.load(File.read(GITHUB_WORKFLOW_FILEPATH))
  update_github_workflow_standard_jobs(workflow)
  fastfile = Fastlane::FastFile.new('fastlane/Fastfile')
  fastfile.runner.available_lanes.each do |lane_name|
    workflow['jobs'][lane_name] = github_job_definition(lane_name)
  end
  File.open(GITHUB_WORKFLOW_FILEPATH, 'w') { |f| f.write workflow.to_yaml }
end

desc 'Builds and releases the new version to Sponsors'
task :release_to_sponsors => [:build, :check_for_blacklisted_requires, :spec, :rubocop, :update_action_ci_jobs] do
  `gem push --key sponsors \
  --host https://rubygems.pkg.github.com/fastlane-plugin-test-center \
  pkg/fastlane-plugin-test_center-#{Fastlane::TestCenter::VERSION}.gem`
end

Rake::Task[:build].enhance [:check_for_blacklisted_requires, :spec, :rubocop]

task default: [:spec, :rubocop]
