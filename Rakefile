require 'bundler/gem_tasks'
require 'colorize'
require 'rspec/core/rake_task'
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
      if (m = /\s+require\s+#{gem_blacklist_regex}/.match(line))
        errors << "require '#{m[:blacklisted_gem]}' found in '#{file}'"
      end
    end
  end
  unless errors.empty?
    errors.each { |line| puts line }
    abort 'Error: blacklisted require(s) found'.red
  end
end

Rake::Task[:release].enhance [:check_for_blacklisted_requires, :spec, :rubocop]

task default: [:spec, :rubocop]
