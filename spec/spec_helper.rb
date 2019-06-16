$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'simplecov'

# SimpleCov.minimum_coverage 95
SimpleCov.start do
  add_group "Actions", "test_center/actions"
  add_group "Helpers", "test_center/helper"
  add_group "MultiScan Helpers", "test_center/helper/multi_scan_manager"
  add_filter "spec"
  add_filter "plugin/test_center.rb"
  add_filter "plugin/test_center/version.rb"
end

# This module is only used to check the environment is currently a testing env
module SpecHelper
end

require 'fastlane' # to import the Action super class
require 'fastlane/plugin/test_center' # import the actual plugin

Fastlane.load_actions # load other actions (in case your plugin calls other actions or shared values)

RSpec.configure do |rspec|
  # This config option will be enabled by default on RSpec 4,
  # but for reasons of backwards compatibility, you have to
  # set it on RSpec 3.
  #
  # It causes the host group and examples to inherit metadata
  # from the shared context.
  rspec.shared_context_metadata_behavior = :apply_to_host_groups
end

RSpec.shared_context "mocked project context", shared_context: :metadata do
  before(:each) do
    allow(Dir).to receive(:exist?).with('path/to/fake_project.xcodeproj').and_return(true)
    @scheme_paths = {
      everyone: 'path/to/fake_project.xcodeproj/xcshareddata/xcschemes/Shared.xcscheme',
      arthur: 'path/to/fake_project.xcodeproj/xcuserdata/auturo/auturo.xcuserdatad/xcschemes/MesaRedonda.xcscheme'
    }
    allow(Dir).to receive(:glob).and_call_original
    allow(Dir).to receive(:glob).with('path/to/fake_project.xcodeproj/{xcshareddata,xcuserdata}/**/xcschemes/*.xcscheme') do
      @scheme_paths.values
    end
    allow(Dir).to receive(:glob).with('path/to/fake_project.xcodeproj/{xcshareddata,xcuserdata}/**/xcschemes/Shared.xcscheme') do
      [@scheme_paths[:everyone]]
    end
    allow(Dir).to receive(:glob).with('path/to/fake_project.xcodeproj/{xcshareddata,xcuserdata}/**/xcschemes/MesaRedonda.xcscheme') do
      [@scheme_paths[:arthur]]
    end
  end
end

RSpec.shared_context "mocked workspace context", shared_context: :metadata do
  before(:each) do
    allow(File).to receive(:directory?).and_call_original
    allow(File).to receive(:directory?).with(%r{.*path/to/fake_workspace.xcworkspace}).and_return(true)
    allow(Dir).to receive(:exist?).with(%r{.*path/to/fake_workspace.xcworkspace}).and_return(true)
    mocked_workspace = OpenStruct.new
    mocked_workspace.file_references = [
      OpenStruct.new(path: 'fake_project.xcodeproj'),
      OpenStruct.new(path: 'Pods/Pods.xcodeproj')
    ]
    allow(mocked_workspace.file_references[0]).to receive(:absolute_path).and_return('path/to/fake_project.xcodeproj')
    allow(Xcodeproj::Workspace).to receive(:new_from_xcworkspace).and_return(mocked_workspace)
  end
end

RSpec.shared_context "mocked schemes context", shared_context: :metadata do
  include_context "mocked project context"
  include_context "mocked workspace context"

  before(:each) do
    @xcschemes = {}
    @scheme_skipped_tests = {}
    @actual_skipped_tests = []
    @scheme_paths.each do |scheme, scheme_path|
      xcscheme = OpenStruct.new
      @xcschemes[scheme] = xcscheme
      xcscheme.test_action = OpenStruct.new
      xcscheme.test_action.testables = [
        OpenStruct.new(
          buildable_references: [
            OpenStruct.new(
              buildable_name: 'BagOfTests.xctest'
            )
          ]
        )
      ]
      xcscheme.test_action.testables[0].skipped_tests = [
        OpenStruct.new(identifier: 'HappyNapperTests/testBeepingNonExistentFriendDisplaysError'),
        OpenStruct.new(identifier: 'GrumpyWorkerTests')
      ]
      if scheme == :everyone
        xcscheme.test_action.testables[0].skipped_tests << OpenStruct.new(identifier: 'HappyNapperTests/testClickSoundMadeWhenBucklingUp')
      end
      allow(xcscheme.test_action.testables[0]).to receive(:add_skipped_test) do |skipped_test|
        @actual_skipped_tests << skipped_test.identifier
      end
      skipped_tests = [OpenStruct.new, OpenStruct.new]
      @scheme_skipped_tests[scheme] = skipped_tests.dup # we will change the list below, so make a shallow copy
      allow(Xcodeproj::XCScheme::TestAction::TestableReference::SkippedTest).to receive(:new) do
        skipped_tests.shift || OpenStruct.new
      end
      allow(Xcodeproj::XCScheme).to receive(:new).with(scheme_path).and_return(xcscheme)
    end
    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:exist?).with('path/to/fake_junit_report.xml').and_return(true)
    allow(File).to receive(:open).and_call_original
    allow(File).to receive(:open).with('path/to/fake_junit_report.xml').and_yield(File.open('./spec/fixtures/junit.xml'))
  end
end
