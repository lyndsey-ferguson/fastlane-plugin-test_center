
lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fastlane/plugin/test_center/version'

Gem::Specification.new do |spec|
  spec.name          = 'fastlane-plugin-test_center'
  spec.version       = Fastlane::TestCenter::VERSION
  spec.author        = 'Lyndsey Ferguson'
  spec.email         = 'ldf.public+github@outlook.com'

  spec.summary       = 'Makes testing your iOS app easier'
  spec.homepage      = "https://github.com/lyndsey-ferguson/fastlane-plugin-test_center"
  spec.license       = "MIT"

  spec.files         = Dir["lib/**/*"] + %w(README.md LICENSE)
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.description = <<-SUMMARY
    This fastlane plugin includes the following many actions to better manage how you test, what you test, and the information you get from your tests
  SUMMARY

  spec.add_dependency 'json'
  spec.add_dependency 'plist'
  spec.add_dependency 'xcodeproj'
  spec.add_dependency 'xctest_list', '>= 1.1.7'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'colorize'
  spec.add_development_dependency 'fastlane', '>= 2.108.0'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'pry-byebug'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'slather'
  spec.add_development_dependency 'xcpretty-json-formatter'
end
