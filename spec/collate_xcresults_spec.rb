module Fastlane::Actions
  describe 'CollateXcresults' do
    it 'a failure occurs when non-existent xcresult is specified' do
      fastfile = "lane :test do
        collate_xcresults(
          xcresults: ['path/to/non_existent.xcresult'],
          collated_xcresult: 'path/to/report.xcresult'
        )
      end"
      expect { Fastlane::FastFile.new.parse(fastfile).runner.execute(:test) }.to(
        raise_error(FastlaneCore::Interface::FastlaneError) do |error|
          expect(error.message).to match("Error: xcresult bundle not found: 'path/to/non_existent.xcresult'")
        end
      )
    end
  end

  describe 'handles valid data' do
    before(:each) do
     allow(File).to receive(:exist?).and_call_original
     allow(Dir).to receive(:exist?).with(%r{path/to/fake(1|2|3)?\.xcresult}).and_return(true)
    end

    it "returns nil when Xcode 10 or earlier" do
      allow(FastlaneCore::Helper).to receive(:xcode_at_least?).and_return(false)
      fastfile = "lane :test do
        collate_xcresults(
          xcresults: ['path/to/fake.xcresult'],
          collated_xcresult: 'path/to/result.xcresult'
        )
      end"
      result = Fastlane::FastFile.new.parse(fastfile).runner.execute(:test)
      expect(result).to be_nil
    end

    it 'simply copies a xcresult bundle when there is only one xcresult bundle' do
      fastfile = "lane :test do
        collate_xcresults(
          xcresults: ['path/to/fake.xcresult'],
          collated_xcresult: 'path/to/result.xcresult'
        )
      end"

      allow(FastlaneCore::Helper).to receive(:xcode_at_least?).and_return(true)
      allow(File).to receive(:realdirpath) do |dirpath|
        dirpath
      end
      allow(FileUtils).to receive(:rm_rf).with('path/to/result.xcresult')
      expect(FileUtils).to receive(:cp_r).with('path/to/fake.xcresult', 'path/to/result.xcresult')
      Fastlane::FastFile.new.parse(fastfile).runner.execute(:test)
    end

    it 'calls xcresulttool merge correctly' do
      mocked_xcresult_tmpfile = OpenStruct.new
      allow(Tempfile).to receive(:new).and_return(mocked_xcresult_tmpfile)
      allow(mocked_xcresult_tmpfile).to receive(:path).and_return('/path/to/tmp/collated_result.xcresult')
      allow(mocked_xcresult_tmpfile).to receive(:unlink)
      allow(FileUtils).to receive(:rm_rf).with('path/to/result.xcresult')
      allow(FileUtils).to receive(:cp_r)
      allow(FastlaneCore::Helper).to receive(:xcode_at_least?).and_return(true)

      fastfile = "lane :test do
        collate_xcresults(
          xcresults: ['path/to/fake.xcresult', 'path/to/fake2.xcresult', 'path/to/fake3.xcresult'],
          collated_xcresult: 'path/to/result.xcresult'
        )
      end"

      expected_result = [
        'xcrun',
        'xcresulttool',
        'merge',
        'path/to/fake.xcresult',
        'path/to/fake2.xcresult',
        'path/to/fake3.xcresult',
        '--output-path',
        '/path/to/tmp/collated_result.xcresult'
      ].join(' ')
      actual_result = Fastlane::FastFile.new.parse(fastfile).runner.execute(:test)
      expect(actual_result).to eq(expected_result)
    end
  end
end

