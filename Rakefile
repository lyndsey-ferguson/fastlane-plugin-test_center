require 'bundler/gem_tasks'
require 'colorize'
require 'rspec/core/rake_task'
require_relative 'fastlane/test_center_utils'
require 'fastlane'
require 'markdown-tables'

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

Rake::Task[:build].enhance [:check_for_blacklisted_requires, :spec, :rubocop]

task default: [:spec, :rubocop]
