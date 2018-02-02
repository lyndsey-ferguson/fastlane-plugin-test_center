describe Fastlane::Actions::TestsFromXctestrunAction do
  describe 'it handles invalid data' do
    it 'a failure occurs when a non-existent xctestrun file is specified' do
      fastfile = "lane :test do
        tests_from_xctestrun(
          xctestrun: 'path/to/non_existent.xctestrun'
        )
      end"
      expect { Fastlane::FastFile.new.parse(fastfile).runner.execute(:test) }.to(
        raise_error(FastlaneCore::Interface::FastlaneError) do |error|
          expect(error.message).to match("Error: cannot find the xctestrun file 'path/to/non_existent.xctestrun'")
        end
      )
    end
  end
end
