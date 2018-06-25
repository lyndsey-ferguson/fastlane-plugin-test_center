require 'plist'
require 'pry-byebug'

info_plist_1 = Plist.parse_xml('./spec/fixtures/AtomicBoy.test_result/Info.plist')
info_plist_2 = Plist.parse_xml('./spec/fixtures/AtomicBoy_0.test_result/Info.plist')
test_summaries_plist_1 = Plist.parse_xml('./spec/fixtures/AtomicBoy.test_result/TestSummaries.plist')
test_summaries_plist_2 = Plist.parse_xml('./spec/fixtures/AtomicBoy_0.test_result/TestSummaries.plist')

describe Fastlane::Actions::CollateTestResultBundlesAction do
  describe 'skip handles invalid data' do
    it 'a failure occurs when non-existent test_result bundle is specified' do
      fastfile = "lane :test do
        collate_test_result_bundles(
          bundles: ['path/to/non_existent.test_result'],
          collated_bundle: 'path/to/report.test_result'
        )
      end"
      expect { Fastlane::FastFile.new.parse(fastfile).runner.execute(:test) }.to(
        raise_error(FastlaneCore::Interface::FastlaneError) do |error|
          expect(error.message).to match("Error: test_result bundle not found: 'path/to/non_existent.test_result'")
        end
      )
    end
  end

  describe 'skip handles valid data' do
    before(:each) do
      allow(File).to receive(:exist?).and_call_original
      allow(Plist).to receive(:parse_xml).and_call_original
      allow(Dir).to receive(:exist?).with(%r{path/to/fake(1|2)?\.test_bundle}).and_return(true)
      allow(Dir).to receive(:mktmpdir).and_return('/tmp/path/to/fake.test_bundle')
      allow(FileUtils).to receive(:cp_r).with('path/to/fake1.test_bundle/.', '/tmp/path/to/fake.test_bundle')
      allow(FileUtils).to receive(:cp_r).with('/tmp/path/to/fake.test_bundle', 'path/to/report.test_bundle')
      allow(Dir).to receive(:foreach).and_call_original
      # allow(Dir).to receive(:exist?).with('path/to/fake1.test_bundle').and_return(true)
      # allow(Dir).to receive(:exist?).with('path/to/fake2.test_bundle').and_return(true)
      # allow(File).to receive(:exist?).with('tmp/path/to/fake.test_bundle/Info.plist').and_return(true)
      # allow(Plist).to receive(:parse_xml).with('tmp/path/to/fake.test_bundle/Info.plist').and_return(info_plist_1)
      # allow(File).to receive(:exist?).with('path/to/fake2.test_bundle/Info.plist').and_return(true)
      # allow(Plist).to receive(:parse_xml).with('path/to/fake2.test_bundle/Info.plist').and_return(info_plist_2)
      # allow(File).to receive(:exist?).with('tmp/path/to/fake.test_bundle/TestSummaries.plist').and_return(true)
      # allow(Plist).to receive(:parse_xml).with('tmp/path/to/fake.test_bundle/TestSummaries.plist').and_return(test_summaries_plist_1)
      # allow(File).to receive(:exist?).with('path/to/fake2.test_bundle/TestSummaries.plist').and_return(true)
      # allow(Plist).to receive(:parse_xml).with('path/to/fake2.test_bundle/TestSummaries.plist').and_return(test_summaries_plist_2)
      # allow(FileUtils).to receive(:cp_r).with(%r{path/to/fake\d?\.test_bundle}, 'tmp/path/to/fake.test_bundle')
      # allow(FileUtils).to receive(:cp_r).with('tmp/path/to/fake.test_bundle', %r{path/to/fake\d?\.test_bundle})
    end

    it 'simply copies a :bundles value containing one test_result bundle' do
      fastfile = "lane :test do
        collate_test_result_bundles(
          bundles: ['path/to/fake.test_bundle'],
          collated_bundle: 'path/to/report.test_bundle'
        )
      end"
      expect(FileUtils).to receive(:cp_r).with('path/to/fake.test_bundle', 'path/to/report.test_bundle')
      Fastlane::FastFile.new.parse(fastfile).runner.execute(:test)
    end

    it 'merges Info.plist files' do
      fastfile = "lane :test do
      collate_test_result_bundles(
        bundles: ['path/to/fake1.test_bundle', 'path/to/fake2.test_bundle'],
        collated_bundle: 'path/to/report.test_bundle'
        )
      end"
      allow(Dir).to receive(:foreach).with('path/to/fake2.test_bundle') do |dirname, &block|
        block.call('Info.plist')
      end
      allow(File).to receive(:exist?).with('/tmp/path/to/fake.test_bundle/Info.plist').and_return(true)
      allow(File).to receive(:exist?).with('path/to/fake2.test_bundle/Info.plist').and_return(true)
      allow(Plist).to receive(:parse_xml).with('/tmp/path/to/fake.test_bundle/Info.plist').and_return(info_plist_1)
      allow(Plist).to receive(:parse_xml).with('path/to/fake2.test_bundle/Info.plist').and_return(info_plist_2)
      expect(Plist::Emit).to receive(:save_plist).with(info_plist_1, '/tmp/path/to/fake.test_bundle/Info.plist')
      Fastlane::FastFile.new.parse(fastfile).runner.execute(:test)
      expect(info_plist_1['Actions'][0]['EndedTime']).to eq(DateTime.parse('2018-06-25T13:32:11Z'))
      expect(info_plist_1['Actions'][0]['ActionResult']['TestsFailedCount']).to eq(3)
    end

    it 'merges TestSummaries.plist files' do
      fastfile = "lane :test do
        collate_test_result_bundles(
          bundles: ['path/to/fake1.test_bundle', 'path/to/fake2.test_bundle'],
          collated_bundle: 'path/to/report.test_bundle'
        )
      end"
      allow(Dir).to receive(:foreach).with('path/to/fake2.test_bundle') do |dirname, &block|
        block.call('TestSummaries.plist')
      end
      allow(File).to receive(:exist?).with('/tmp/path/to/fake.test_bundle/TestSummaries.plist').and_return(true)
      allow(File).to receive(:exist?).with('path/to/fake2.test_bundle/TestSummaries.plist').and_return(true)
      allow(Plist).to receive(:parse_xml).with('/tmp/path/to/fake.test_bundle/TestSummaries.plist').and_return(test_summaries_plist_1)
      allow(Plist).to receive(:parse_xml).with('path/to/fake2.test_bundle/TestSummaries.plist').and_return(test_summaries_plist_2)

      expect(Plist::Emit).to receive(:save_plist).with(test_summaries_plist_1, '/tmp/path/to/fake.test_bundle/TestSummaries.plist')

      original_tests = test_summaries_plist_1['TestableSummaries'][0]['Tests']
      Fastlane::FastFile.new.parse(fastfile).runner.execute(:test)
      expect(test_summaries_plist_1['TestableSummaries'][0]['PreviousTests']).to eq(original_tests)
      expect(test_summaries_plist_1['TestableSummaries'][0]['PreviousTests'].size).to eq(1)
      expect(test_summaries_plist_1['TestableSummaries'][0]['Tests']).to eq(test_summaries_plist_2['TestableSummaries'][0]['Tests'])
    end

    it 'merges test target\'s TestSummaries.plist' do
      fastfile = "lane :test do
        collate_test_result_bundles(
          bundles: ['path/to/fake1.test_bundle', 'path/to/fake2.test_bundle'],
          collated_bundle: 'path/to/report.test_bundle'
        )
      end"
      allow(Dir).to receive(:foreach).with('path/to/fake2.test_bundle') do |dirname, &block|
        block.call('1_Test')
      end
      allow(Dir).to receive(:foreach).with('path/to/fake2.test_bundle/1_Test') do |dirname, &block|
        block.call('action_TestSummaries.plist')
      end
      expect(Fastlane::Actions::CollateTestResultBundlesAction)
        .to receive(:collate_testsummaries_plist)
        .with(
          '/tmp/path/to/fake.test_bundle/1_Test/action_TestSummaries.plist',
          'path/to/fake2.test_bundle/1_Test/action_TestSummaries.plist'
        )

      Fastlane::FastFile.new.parse(fastfile).runner.execute(:test)
    end

    it 'merges Attachments directory' do
      fastfile = "lane :test do
        collate_test_result_bundles(
          bundles: ['path/to/fake1.test_bundle', 'path/to/fake2.test_bundle'],
          collated_bundle: 'path/to/report.test_bundle'
        )
      end"
      allow(Dir).to receive(:foreach).with('path/to/fake2.test_bundle') do |dirname, &block|
        block.call('Attachments')
      end
      expect(FileUtils).to receive(:cp_r).with('path/to/fake2.test_bundle/Attachments/.', '/tmp/path/to/fake.test_bundle/Attachments')
      Fastlane::FastFile.new.parse(fastfile).runner.execute(:test)
    end

    it 'merges test target\'s Attachments directories' do
      fastfile = "lane :test do
        collate_test_result_bundles(
          bundles: ['path/to/fake1.test_bundle', 'path/to/fake2.test_bundle'],
          collated_bundle: 'path/to/report.test_bundle'
        )
      end"
      allow(Dir).to receive(:foreach).with('path/to/fake2.test_bundle') do |dirname, &block|
        block.call('1_Test')
      end
      allow(Dir).to receive(:foreach).with('path/to/fake2.test_bundle/1_Test') do |dirname, &block|
        block.call('Attachments')
      end
      expect(FileUtils).to receive(:cp_r).with('path/to/fake2.test_bundle/1_Test/Attachments/.', '/tmp/path/to/fake.test_bundle/1_Test/Attachments')
      Fastlane::FastFile.new.parse(fastfile).runner.execute(:test)
    end

    it 'merges test target\'s Diagnostics directories' do
      fastfile = "lane :test do
        collate_test_result_bundles(
          bundles: ['path/to/fake1.test_bundle', 'path/to/fake2.test_bundle'],
          collated_bundle: 'path/to/report.test_bundle'
        )
      end"
      allow(Dir).to receive(:foreach).with('path/to/fake2.test_bundle') do |dirname, &block|
        block.call('1_Test')
      end
      allow(Dir).to receive(:foreach).with('path/to/fake2.test_bundle/1_Test') do |dirname, &block|
        block.call('Diagnostics')
      end
      expect(FileUtils).to receive(:cp_r).with('path/to/fake2.test_bundle/1_Test/Diagnostics/.', '/tmp/path/to/fake.test_bundle/1_Test/Diagnostics')
      Fastlane::FastFile.new.parse(fastfile).runner.execute(:test)
    end

    it 'merges test target\'s xcactivitylogs' do
      fastfile = "lane :test do
        collate_test_result_bundles(
          bundles: ['path/to/fake1.test_bundle', 'path/to/fake2.test_bundle'],
          collated_bundle: 'path/to/report.test_bundle'
        )
      end"
      allow(Dir).to receive(:foreach).with('path/to/fake2.test_bundle') do |dirname, &block|
        block.call('1_Test')
      end
      activity_logfiles = ['action.xcactivitylog', 'build.xcactivitylog']
      allow(Dir).to receive(:foreach).with('path/to/fake2.test_bundle/1_Test') do |dirname, &block|
        activity_logfiles.each { |logfile| block.call(logfile) }
      end

      expect(Fastlane::Actions::CollateTestResultBundlesAction)
        .to receive(:concatenate_zipped_activitylogs)
        .with(
          '/tmp/path/to/fake.test_bundle/1_Test/action.xcactivitylog',
          'path/to/fake2.test_bundle/1_Test/action.xcactivitylog'
        )

      expect(Fastlane::Actions::CollateTestResultBundlesAction)
        .to receive(:concatenate_zipped_activitylogs)
        .with(
          '/tmp/path/to/fake.test_bundle/1_Test/build.xcactivitylog',
          'path/to/fake2.test_bundle/1_Test/build.xcactivitylog'
        )

      Fastlane::FastFile.new.parse(fastfile).runner.execute(:test)
    end

    it 'concatenates zipped files in the expected manner' do
      expect(Fastlane::Action).to receive(:sh).with('gunzip -k -S .xcactivitylog path/to/fake2.test_bundle/1_Test/action.xcactivitylog', print_command: false, print_command_output: false)
      expect(Fastlane::Action).to receive(:sh).with('gunzip -S .xcactivitylog /tmp/path/to/fake.test_bundle/1_Test/action.xcactivitylog', print_command: false, print_command_output: false)
      expect(Fastlane::Action).to receive(:sh).with('cat path/to/fake2.test_bundle/1_Test/action > /tmp/path/to/fake.test_bundle/1_Test/action', print_command: false, print_command_output: false)
      expect(FileUtils).to receive(:rm).with('path/to/fake2.test_bundle/1_Test/action')
      expect(Fastlane::Action).to receive(:sh).with('gzip -S .xcactivitylog /tmp/path/to/fake.test_bundle/1_Test/action', print_command: false, print_command_output: false)

      Fastlane::Actions::CollateTestResultBundlesAction.concatenate_zipped_activitylogs(
        '/tmp/path/to/fake.test_bundle/1_Test/action.xcactivitylog',
        'path/to/fake2.test_bundle/1_Test/action.xcactivitylog'
      )
    end
  end
end
