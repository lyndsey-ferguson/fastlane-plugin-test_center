require 'fastlane'
require 'fastlane/actions/scan'

FASTFILE_DIRECTORY = File.dirname(File.dirname(__FILE__))

def action_info
  examples = Hash.new { |h, k| h[k] = [] }
  integration_tests = Hash.new { |h, k| h[k] = [] }
  options = Hash.new { |h, k| h[k] = [] }
  scan_keys = Fastlane::Actions::ScanAction.available_options.map(&:key)

  action_filepaths = Dir[File.join(FASTFILE_DIRECTORY, 'lib/fastlane/plugin/test_center/actions/*.rb')]
  action_filepaths.each do |action_filepath|
    require action_filepath
    action_name = File.basename(action_filepath).gsub('.rb', '')
    action_class_name = action_name.fastlane_class + 'Action'

    action_class_ref = Fastlane::Actions.const_get(action_class_name)
    if action_class_ref.respond_to?(:example_code) && action_class_ref.example_code
      examples[action_name] = action_class_ref.example_code
    end
    if action_class_ref.respond_to?(:integration_tests) && action_class_ref.integration_tests
      integration_tests[action_name] = action_class_ref.integration_tests
    end

    if action_class_ref.respond_to?(:available_options) && action_class_ref.available_options
      available_options = action_class_ref.available_options
      if action_name == 'multi_scan'
        available_options.reject! { |config_item| scan_keys.include?(config_item.key) }
      end
      options[action_name] = available_options.map do |config_item|
        {
          key: config_item.key,
          description: config_item.description,
          default_value: config_item.default_value.to_s
        }
      end
    end
  end
  [examples, options, integration_tests]
end
