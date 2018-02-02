describe Fastlane::Actions::SuppressTestsFromJunitAction do
  describe 'it handles invalid data' do
    describe 'no project or workspace in the current working directory' do
      it 'a failure occurs when a non-existent project is given' do
        non_existent_project = "lane :test do
          suppress_tests_from_junit(
            xcodeproj: 'path/to/non_existent_project.xcodeproj',
            junit: 'path/to/non_existent_junit_report.xml',
            suppress_type: :failed,
          )
        end"

        expect { Fastlane::FastFile.new.parse(non_existent_project).runner.execute(:test) }.to(
          raise_error(FastlaneCore::Interface::FastlaneError) do |error|
            expect(error.message).to match(%r{Error: Xcode project 'path/to/non_existent_project.xcodeproj' not found!})
          end
        )
      end

      it 'a failure occurs when a no project is given' do
        non_existent_project = "lane :test do
          suppress_tests_from_junit(
            xcodeproj: '',
            junit: 'path/to/non_existent_junit_report.xml',
            suppress_type: :failed,
          )
        end"

        expect { Fastlane::FastFile.new.parse(non_existent_project).runner.execute(:test) }.to(
          raise_error(FastlaneCore::Interface::FastlaneError) do |error|
            expect(error.message).to match(/Error: Xcode project file path not given!/)
          end
        )
      end
    end

    describe 'a project or workspace exists' do
      include_context "mocked project context"

      it 'a failure occurs when a non-existent Scheme is specified' do
        fastfile = "lane :test do
          suppress_tests_from_junit(
            xcodeproj: 'path/to/fake_project.xcodeproj',
            junit: 'path/to/non_existent_junit_report.xml',
            suppress_type: :failed,
            scheme: 'HolyGrail'
          )
        end"
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with('path/to/non_existent_junit_report.xml').and_return(true)
        expect { Fastlane::FastFile.new.parse(fastfile).runner.execute(:test) }.to(
          raise_error(FastlaneCore::Interface::FastlaneError) do |error|
            expect(error.message).to match("Error: cannot find any scheme named HolyGrail")
          end
        )
      end

      it 'a failure occurs when a non-existent Junit file is specified' do
        fastfile = "lane :test do
          suppress_tests_from_junit(
            xcodeproj: 'path/to/fake_project.xcodeproj',
            junit: 'path/to/non_existent_junit_report.xml',
            suppress_type: :failed,
            scheme: 'HolyGrail'
          )
        end"
        allow(Dir).to receive(:glob).with('path/to/fake_project.xcodeproj/{xcshareddata,xcuserdata}/**/xcschemes/HolyGrail.xcscheme') do
          ['path/to/HolyGrail.xscheme']
        end
        expect { Fastlane::FastFile.new.parse(fastfile).runner.execute(:test) }.to(
          raise_error(FastlaneCore::Interface::FastlaneError) do |error|
            expect(error.message).to match("Error: cannot find the junit xml report file 'path/to/non_existent_junit_report.xml'")
          end
        )
      end

      it 'a failure occurs when an invalid :suppress_type is provided' do
        fastfile = "lane :test do
          suppress_tests_from_junit(
            xcodeproj: 'path/to/fake_project.xcodeproj',
            junit: 'path/to/non_existent_junit_report.xml',
            suppress_type: :doggy
          )
        end"

        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with('path/to/non_existent_junit_report.xml').and_return(true)
        expect { Fastlane::FastFile.new.parse(fastfile).runner.execute(:test) }.to(
          raise_error(FastlaneCore::Interface::FastlaneError) do |error|
            expect(error.message).to match("Error: suppress type ':doggy' is invalid! Only :failed or :passing are valid types")
          end
        )
      end
    end

    describe "a project with schemes and a junit report file exist in the current working directory" do
      include_context "mocked schemes context"

      it 'failed suppressed tests appear in the all Xcode Schemes' do
        fastfile = "lane :test do
          suppress_tests_from_junit(
            xcodeproj: 'path/to/fake_project.xcodeproj',
            junit: 'path/to/fake_junit_report.xml',
            suppress_type: :failed
          )
        end"

        expect(@xcschemes[:everyone]).to receive(:save!)
        expect(@xcschemes[:arthur]).to receive(:save!)
        Fastlane::FastFile.new.parse(fastfile).runner.execute(:test)
        expect(@actual_skipped_tests).to include(
          'CoinTossingUITests/testResultIsTails()'
        )
      end

      it 'passing suppressed tests appear in the all Xcode Schemes' do
        fastfile = "lane :test do
          suppress_tests_from_junit(
            xcodeproj: 'path/to/fake_project.xcodeproj',
            junit: 'path/to/fake_junit_report.xml',
            suppress_type: :passing
          )
        end"

        expect(@xcschemes[:everyone]).to receive(:save!)
        expect(@xcschemes[:arthur]).to receive(:save!)
        Fastlane::FastFile.new.parse(fastfile).runner.execute(:test)
        expect(@actual_skipped_tests).to include(
          'CoinTossingUITests/testResultIsHeads()'
        )
      end

      it 'passing suppressed tests appear in a given Xcode Schemes' do
        fastfile = "lane :test do
          suppress_tests_from_junit(
            xcodeproj: 'path/to/fake_project.xcodeproj',
            junit: 'path/to/fake_junit_report.xml',
            suppress_type: :passing,
            scheme: 'Shared',
          )
        end"

        expect(@xcschemes[:everyone]).to receive(:save!)
        expect(@xcschemes[:arthur]).not_to receive(:save!)
        Fastlane::FastFile.new.parse(fastfile).runner.execute(:test)
        expect(@actual_skipped_tests).to include(
          'CoinTossingUITests/testResultIsHeads()'
        )
      end
    end
  end
end
