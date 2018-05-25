require 'bundler/gem_tasks'
require 'colorize'
require 'rspec/core/rake_task'
require_relative 'fastlane/test_center_utils'
require 'fastlane'

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
end

desc 'Updates the README with the latest examples for each action'
task :update_readme_action_examples do
  readme = File.read('README.md')
  examples = action_examples
  placeholder_example_begin_found = false
  File.open('README.md', 'w') do |file|
    action_name = nil
    readme.lines do |line|
      if /<!-- (?<found_action_name>\w+) examples: begin -->/ =~ line
        placeholder_example_begin_found = true
        action_name = found_action_name
      elsif placeholder_example_begin_found
        if /<!-- #{action_name} examples: end -->/ =~ line
          file.puts "<!-- #{action_name} examples: begin -->"
          examples[action_name].each do |example_code_snippet|
            file.puts ''
            file.puts '```ruby'
            example_code_snippet.lines do |example_code_snippet_line|
              file.puts example_code_snippet_line.sub('          ', '')
            end
            file.puts '```'
          end
          file.puts "<!-- #{action_name} examples: end -->"
          placeholder_example_begin_found = false
        end
      else
        file.puts line
      end
    end
  end
end

Rake::Task[:build].enhance [:check_for_blacklisted_requires, :spec, :rubocop]

task default: [:spec, :rubocop]
