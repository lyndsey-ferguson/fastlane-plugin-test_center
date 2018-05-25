

FASTFILE_DIRECTORY = File.dirname(File.dirname(__FILE__))

def action_examples
  examples = Hash.new { |h, k| h[k] = [] }
  action_filepaths = Dir[File.join(FASTFILE_DIRECTORY, 'lib/fastlane/plugin/test_center/actions/*.rb')]
  action_filepaths.each do |action_filepath|
    require action_filepath
    action_name = File.basename(action_filepath).gsub('.rb', '')
    action_class_name = action_name.fastlane_class + 'Action'

    action_class_ref = Fastlane::Actions.const_get(action_class_name)
    next unless action_class_ref.respond_to?(:example_code)
    next unless action_class_ref.example_code

    examples[action_name] = action_class_ref.example_code
  end
  examples
end
