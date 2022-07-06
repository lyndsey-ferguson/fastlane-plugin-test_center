describe Fastlane::Actions::TestsFromXcresultAction do
  describe 'it handles invalid data' do
    it 'a failure occurs when a non-existent xcresult file is specified' do
      fastfile = "lane :test do
        tests_from_xcresult(
          xcresult: 'path/to/non-existent.xcresult'
        )
      end"

      expect { Fastlane::FastFile.new.parse(fastfile).runner.execute(:test) }.to(
        raise_error(FastlaneCore::Interface::FastlaneError) do |error|
          expect(error.message).to match("Error: cannot find the xcresult bundle at 'path/to/non-existent.xcresult'")
        end
      )
    end
  end

  it "returns all tests in an xcresult bundle" do
    skip "This only works from Xcode 11+" unless FastlaneCore::Helper.xcode_at_least?('11.0.0')

    fastfile = "lane :test do
      tests_from_xcresult(
        xcresult: '../spec/fixtures/AtomicBoy.xcresult'
      )
    end"
    allow(Fastlane::Helper).to receive(:sh_enabled?).and_return(true)
    result = Fastlane::FastFile.new.parse(fastfile).runner.execute(:test)

    expect(result[:failed]).to contain_exactly(
      "AtomicBoyUITests/AtomicBoyUITests/testExample11",
      "AtomicBoyUITests/AtomicBoyUITests/testExample12",
      "AtomicBoyUITests/AtomicBoyUITests/testExample13",
      "AtomicBoyUITests/AtomicBoyUITests/testExample18",
      "AtomicBoyUITests/AtomicBoyUITests/testExample21",
      "AtomicBoyUITests/AtomicBoyUITests/testExample22",
      "AtomicBoyUITests/AtomicBoyUITests/testExample25",
      "AtomicBoyUITests/AtomicBoyUITests/testExample26",
      "AtomicBoyUITests/AtomicBoyUITests/testExample27",
      "AtomicBoyUITests/AtomicBoyUITests/testExample28",
      "AtomicBoyUITests/AtomicBoyUITests/testExample30",
      "AtomicBoyUITests/AtomicBoyUITests/testExample32",
      "AtomicBoyUITests/AtomicBoyUITests/testExample40",
      "AtomicBoyUITests/AtomicBoyUITests/testExample43",
      "AtomicBoyUITests/AtomicBoyUITests/testExample44",
      "AtomicBoyUITests/AtomicBoyUITests/testExample45",
      "AtomicBoyUITests/AtomicBoyUITests/testExample6",
      "AtomicBoyUITests/AtomicBoyUITests/testExample8"
    )
    expect(result[:passing]).to contain_exactly(
      "AtomicBoyUITests/AtomicBoyUITests/testExample",
      "AtomicBoyUITests/AtomicBoyUITests/testExample10",
      "AtomicBoyUITests/AtomicBoyUITests/testExample14",
      "AtomicBoyUITests/AtomicBoyUITests/testExample15",
      "AtomicBoyUITests/AtomicBoyUITests/testExample16",
      "AtomicBoyUITests/AtomicBoyUITests/testExample17",
      "AtomicBoyUITests/AtomicBoyUITests/testExample19",
      "AtomicBoyUITests/AtomicBoyUITests/testExample2",
      "AtomicBoyUITests/AtomicBoyUITests/testExample20",
      "AtomicBoyUITests/AtomicBoyUITests/testExample23",
      "AtomicBoyUITests/AtomicBoyUITests/testExample24",
      "AtomicBoyUITests/AtomicBoyUITests/testExample29",
      "AtomicBoyUITests/AtomicBoyUITests/testExample3",
      "AtomicBoyUITests/AtomicBoyUITests/testExample31",
      "AtomicBoyUITests/AtomicBoyUITests/testExample33",
      "AtomicBoyUITests/AtomicBoyUITests/testExample34",
      "AtomicBoyUITests/AtomicBoyUITests/testExample35",
      "AtomicBoyUITests/AtomicBoyUITests/testExample36",
      "AtomicBoyUITests/AtomicBoyUITests/testExample37",
      "AtomicBoyUITests/AtomicBoyUITests/testExample38",
      "AtomicBoyUITests/AtomicBoyUITests/testExample39",
      "AtomicBoyUITests/AtomicBoyUITests/testExample4",
      "AtomicBoyUITests/AtomicBoyUITests/testExample41",
      "AtomicBoyUITests/AtomicBoyUITests/testExample42",
      "AtomicBoyUITests/AtomicBoyUITests/testExample46",
      "AtomicBoyUITests/AtomicBoyUITests/testExample47",
      "AtomicBoyUITests/AtomicBoyUITests/testExample48",
      "AtomicBoyUITests/AtomicBoyUITests/testExample5",
      "AtomicBoyUITests/AtomicBoyUITests/testExample7",
      "AtomicBoyUITests/AtomicBoyUITests/testExample9",
      "AtomicBoyUITests/CobaltDog/testExample",
      "AtomicBoyUITests/SwiftAtomicBoyUITests/testExample"
    )
  end

  it 'returns "expected failures" found in an xcresult bundle' do
    skip "This only works from Xcode 11+" unless FastlaneCore::Helper.xcode_at_least?('11.0.0')

    fastfile = "lane :test do
      tests_from_xcresult(
        xcresult: '../spec/fixtures/Test-AtomicBoy-ExpectedFailures.xcresult'
      )
    end"
    allow(Fastlane::Helper).to receive(:sh_enabled?).and_return(true)
    result = Fastlane::FastFile.new.parse(fastfile).runner.execute(:test)

    expect(result[:expected_failures]).to eq(["AtomicBoyUITests/CobaltDog/testExample"])
  end
end
