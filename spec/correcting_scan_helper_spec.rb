CorrectingScanHelper = TestCenter::Helper::CorrectingScanHelper
describe TestCenter do
  describe TestCenter::Helper do
    describe CorrectingScanHelper do
      describe 'scan' do
        before(:each) do
          @mock_reportnamer = OpenStruct.new
          allow(TestCenter::Helper::ReportNameHelper).to receive(:new).and_return(@mock_reportnamer)

          @mock_testcollector = OpenStruct.new
          allow(TestCenter::Helper::TestCollector).to receive(:new).and_return(@mock_testcollector)
        end

        it 'calls scan_testable for each testable' do
          allow(@mock_testcollector).to receive(:testables).and_return(['AtomicBoyTests'])
          scanner = CorrectingScanHelper.new(
            xctestrun: 'path/to/fake.xctestrun'
          )
          expect(scanner).to receive(:scan_testable).with('AtomicBoyTests').and_return(true).once
          results = scanner.scan
          expect(results).to eq(true)

          allow(@mock_testcollector).to receive(:testables).and_return(['AtomicBoyTests', 'AtomicBoyUITests'])
          scanner = CorrectingScanHelper.new(
            xctestrun: 'path/to/fake.xctestrun'
          )
          expect(scanner).to receive(:scan_testable).with('AtomicBoyTests').and_return(false).ordered.once
          expect(scanner).to receive(:scan_testable).with('AtomicBoyUITests').and_return(true).ordered.once
          results = scanner.scan
          expect(results).to eq(false)
        end

        it 'scan calls correcting_scan once for one testable' do
          scanner = CorrectingScanHelper.new(
            xctestrun: 'path/to/fake.xctestrun',
            output_directory: '.'
          )
          allow(@mock_testcollector).to receive(:testables).and_return(['AtomicBoyTests'])
          expect(@mock_testcollector).not_to receive(:testables_tests)
          expect(scanner).to receive(:correcting_scan).with({ output_directory: '.' }, @mock_reportnamer)
          expect(scanner).not_to receive(:correcting_scan).with(only_testing: anything)
          expect(scanner).to receive(:collate_reports)
          scanner.scan
        end

        it 'scan calls correcting_scan once for each of two testables' do
          scanner = CorrectingScanHelper.new(
            xctestrun: 'path/to/fake.xctestrun',
            output_directory: '.'
          )
          allow(@mock_testcollector).to receive(:testables).and_return(['AtomicBoyTests', 'AtomicBoyUITests'])
          expect(@mock_testcollector).to receive(:testables_tests).and_return(
            {
              'AtomicBoyTests' => [
                'AtomicBoyTests/AtomicBoyTests/testExample1',
                'AtomicBoyTests/AtomicBoyTests/testExample2',
                'AtomicBoyTests/AtomicBoyTests/testExample3',
                'AtomicBoyTests/AtomicBoyTests/testExample4'
              ],
              'AtomicBoyUITests' => [
                'AtomicBoyUITests/AtomicBoyUITests/testExample1',
                'AtomicBoyUITests/AtomicBoyUITests/testExample2',
                'AtomicBoyUITests/AtomicBoyUITests/testExample3',
                'AtomicBoyUITests/AtomicBoyUITests/testExample4'
              ]
            }
          ).twice
          expect(scanner).to receive(:correcting_scan)
            .with(
              {
                only_testing: [
                  'AtomicBoyTests/AtomicBoyTests/testExample1',
                  'AtomicBoyTests/AtomicBoyTests/testExample2',
                  'AtomicBoyTests/AtomicBoyTests/testExample3',
                  'AtomicBoyTests/AtomicBoyTests/testExample4'
                ],
                output_directory: './results-AtomicBoyTests'
              },
              @mock_reportnamer
            )
            .and_return(true)
            .ordered
            .once
          expect(scanner).to receive(:correcting_scan)
            .with(
              {
                only_testing: [
                  'AtomicBoyUITests/AtomicBoyUITests/testExample1',
                  'AtomicBoyUITests/AtomicBoyUITests/testExample2',
                  'AtomicBoyUITests/AtomicBoyUITests/testExample3',
                  'AtomicBoyUITests/AtomicBoyUITests/testExample4'
                ],
                output_directory: './results-AtomicBoyUITests'
              },
              @mock_reportnamer
            )
            .and_return(false)
            .ordered
            .once
          expect(scanner).to receive(:collate_reports).twice
          results = scanner.scan
          expect(results).to eq(false)
        end

        it 'scan calls correcting_scan twice for each batch in one testable' do
          scanner = CorrectingScanHelper.new(
            xctestrun: 'path/to/fake.xctestrun',
            batch_count: 2,
            output_directory: '.'
          )
          allow(@mock_testcollector).to receive(:testables).and_return(['AtomicBoyTests'])
          expect(@mock_testcollector).to receive(:testables_tests).and_return(
            {
              'AtomicBoyTests' => [
                'AtomicBoyTests/AtomicBoyTests/testExample1',
                'AtomicBoyTests/AtomicBoyTests/testExample2',
                'AtomicBoyTests/AtomicBoyTests/testExample3',
                'AtomicBoyTests/AtomicBoyTests/testExample4'
              ]
            }
          )
          expect(scanner).to receive(:correcting_scan)
            .with(
              {
                only_testing: [
                  'AtomicBoyTests/AtomicBoyTests/testExample1',
                  'AtomicBoyTests/AtomicBoyTests/testExample2'
                ],
                output_directory: '.'
              },
              @mock_reportnamer
            )
            .and_return(true)
            .ordered
            .once
          expect(scanner).to receive(:correcting_scan)
            .with(
              {
                only_testing: [
                  'AtomicBoyTests/AtomicBoyTests/testExample3',
                  'AtomicBoyTests/AtomicBoyTests/testExample4'
                ],
                output_directory: '.'
              },
              @mock_reportnamer
            )
            .and_return(true)
            .ordered
            .once
          expect(scanner).to receive(:collate_reports)
          results = scanner.scan
          expect(results).to eq(true)
        end

        it 'scan calls correcting_scan twice for each batch in two testables' do
          scanner = CorrectingScanHelper.new(
            xctestrun: 'path/to/fake.xctestrun',
            batch_count: 2,
            output_directory: '.'
          )
          allow(@mock_testcollector).to receive(:testables).and_return(['AtomicBoyTests', 'AtomicBoyUITests'])
          expect(@mock_testcollector).to receive(:testables_tests).and_return(
            {
              'AtomicBoyTests' => [
                'AtomicBoyTests/AtomicBoyTests/testExample1',
                'AtomicBoyTests/AtomicBoyTests/testExample2',
                'AtomicBoyTests/AtomicBoyTests/testExample3',
                'AtomicBoyTests/AtomicBoyTests/testExample4'
              ],
              'AtomicBoyUITests' => [
                'AtomicBoyUITests/AtomicBoyUITests/testExample1',
                'AtomicBoyUITests/AtomicBoyUITests/testExample2',
                'AtomicBoyUITests/AtomicBoyUITests/testExample3',
                'AtomicBoyUITests/AtomicBoyUITests/testExample4'
              ]
            }
          ).twice
          expect(scanner).to receive(:correcting_scan)
            .with(
              {
                only_testing: [
                  'AtomicBoyTests/AtomicBoyTests/testExample1',
                  'AtomicBoyTests/AtomicBoyTests/testExample2'
                ],
                output_directory: './results-AtomicBoyTests'
              },
              @mock_reportnamer
            )
            .and_return(true)
            .ordered
            .once
          expect(scanner).to receive(:correcting_scan)
            .with(
              {
                only_testing: [
                  'AtomicBoyTests/AtomicBoyTests/testExample3',
                  'AtomicBoyTests/AtomicBoyTests/testExample4'
                ],
                output_directory: './results-AtomicBoyTests'
              },
              @mock_reportnamer
            )
            .and_return(false)
            .ordered
            .once
          expect(scanner).to receive(:correcting_scan)
            .with(
              {
                only_testing: [
                  'AtomicBoyUITests/AtomicBoyUITests/testExample1',
                  'AtomicBoyUITests/AtomicBoyUITests/testExample2'
                ],
                output_directory: './results-AtomicBoyUITests'
              },
              @mock_reportnamer
            )
            .and_return(true)
            .ordered
            .once
          expect(scanner).to receive(:correcting_scan)
            .with(
              {
                only_testing: [
                  'AtomicBoyUITests/AtomicBoyUITests/testExample3',
                  'AtomicBoyUITests/AtomicBoyUITests/testExample4'
                ],
                output_directory: './results-AtomicBoyUITests'
              },
              @mock_reportnamer
            )
            .and_return(true)
            .ordered
            .once
          expect(scanner).to receive(:collate_reports).twice
          results = scanner.scan
          expect(results).to eq(false)
        end

        it 'scan calls correcting_scan with :skip_testing with two testables' do
          scanner = CorrectingScanHelper.new(
            xctestrun: 'path/to/fake.xctestrun',
            output_directory: '.',
            skip_testing: [
              'AtomicBoyTests/AtomicBoyTests/testExample2',
              'AtomicBoyTests/AtomicBoyTests/testExample3',
              'AtomicBoyUITests/AtomicBoyUITests/testExample4'
            ]
          )
          allow(@mock_testcollector).to receive(:testables).and_return(['AtomicBoyTests', 'AtomicBoyUITests'])
          allow(File).to receive(:exist?).with('path/to/fake.xctestrun').and_return(true)
          allow(@mock_testcollector).to receive(:testables_tests)
            .and_return(
              'AtomicBoyTests' => [
                'AtomicBoyTests/AtomicBoyTests/testExample1',
                'AtomicBoyTests/AtomicBoyTests/testExample4'
              ],
              'AtomicBoyUITests' => [
                'AtomicBoyUITests/AtomicBoyUITests/testExample1',
                'AtomicBoyUITests/AtomicBoyUITests/testExample2',
                'AtomicBoyUITests/AtomicBoyUITests/testExample3'
              ]
            )

          expect(scanner).to receive(:correcting_scan)
            .with(
              {
                only_testing: [
                  'AtomicBoyTests/AtomicBoyTests/testExample1',
                  'AtomicBoyTests/AtomicBoyTests/testExample4'
                ],
                output_directory: './results-AtomicBoyTests'
              },
              @mock_reportnamer
            )
            .and_return(false)
            .ordered
            .once
          expect(scanner).to receive(:correcting_scan)
            .with(
              {
                only_testing: [
                  'AtomicBoyUITests/AtomicBoyUITests/testExample1',
                  'AtomicBoyUITests/AtomicBoyUITests/testExample2',
                  'AtomicBoyUITests/AtomicBoyUITests/testExample3'
                ],
                output_directory: './results-AtomicBoyUITests'
              },
              @mock_reportnamer
            )
            .and_return(true)
            .ordered
            .once
          expect(scanner).to receive(:collate_reports).twice
          results = scanner.scan
          expect(results).to eq(false)
        end

        it 'scan calls correcting_scan twice each with one batch of tests minus :skipped_testing items for one testable' do
          scanner = CorrectingScanHelper.new(
            xctestrun: 'path/to/fake.xctestrun',
            output_directory: '.',
            batch_count: 2,
            skip_testing: [
              'AtomicBoyTests/AtomicBoyTests/testExample2',
              'AtomicBoyTests/AtomicBoyTests/testExample3',
              'AtomicBoyUITests/AtomicBoyUITests/testExample4'
            ]
          )
          allow(@mock_testcollector).to receive(:testables).and_return(['AtomicBoyTests'])
          allow(File).to receive(:exist?).with('path/to/fake.xctestrun').and_return(true)
          # pretend that @mock_testcollector is doing its job and parsed out the tests in skip_testing
          allow(@mock_testcollector).to receive(:testables_tests)
            .and_return(
              'AtomicBoyTests' => [
                'AtomicBoyTests/AtomicBoyTests/testExample1',
                'AtomicBoyTests/AtomicBoyTests/testExample4'
              ]
            )
          expect(scanner).to receive(:correcting_scan)
            .with(
              {
                only_testing: [
                  'AtomicBoyTests/AtomicBoyTests/testExample1'
                ],
                output_directory: '.'
              },
              @mock_reportnamer
            )
            .and_return(true)
            .ordered
            .once
          expect(scanner).to receive(:correcting_scan)
            .with(
              {
                only_testing: [
                  'AtomicBoyTests/AtomicBoyTests/testExample4'
                ],
                output_directory: '.'
              },
              @mock_reportnamer
            )
            .and_return(true)
            .ordered
            .once
          expect(scanner).to receive(:collate_reports)
          results = scanner.scan
          expect(results).to eq(true)
        end

        it 'scan calls correcting_scan twice each with one batch of tests minus :skipped_testing items for two testables' do
          scanner = CorrectingScanHelper.new(
            xctestrun: 'path/to/fake.xctestrun',
            output_directory: '.',
            batch_count: 2,
            skip_testing: [
              'AtomicBoyTests/AtomicBoyTests/testExample2',
              'AtomicBoyTests/AtomicBoyTests/testExample3',
              'AtomicBoyUITests/AtomicBoyUITests/testExample4'
            ]
          )
          allow(@mock_testcollector).to receive(:testables).and_return(['AtomicBoyTests', 'AtomicBoyUITests'])
          allow(File).to receive(:exist?).with('path/to/fake.xctestrun').and_return(true)
          allow(@mock_testcollector).to receive(:testables_tests)
            .and_return(
              'AtomicBoyTests' => [
                'AtomicBoyTests/AtomicBoyTests/testExample1',
                'AtomicBoyTests/AtomicBoyTests/testExample4'
              ],
              'AtomicBoyUITests' => [
                'AtomicBoyUITests/AtomicBoyUITests/testExample1',
                'AtomicBoyUITests/AtomicBoyUITests/testExample2',
                'AtomicBoyUITests/AtomicBoyUITests/testExample3'
              ]
            )
          expect(scanner).to receive(:correcting_scan)
            .with(
              {
                only_testing: [
                  'AtomicBoyTests/AtomicBoyTests/testExample1'
                ],
                output_directory: './results-AtomicBoyTests'
              },
              @mock_reportnamer
            ).and_return(true)
            .ordered
            .once
          expect(scanner).to receive(:correcting_scan)
            .with(
              {
                only_testing: [
                  'AtomicBoyTests/AtomicBoyTests/testExample4'
                ],
                output_directory: './results-AtomicBoyTests'
              },
              @mock_reportnamer
            )
            .and_return(true)
            .ordered
            .once
          expect(scanner).to receive(:correcting_scan)
            .with(
              {
                only_testing: [
                  'AtomicBoyUITests/AtomicBoyUITests/testExample1',
                  'AtomicBoyUITests/AtomicBoyUITests/testExample2'
                ],
                output_directory: './results-AtomicBoyUITests'
              },
              @mock_reportnamer
            )
            .and_return(true)
            .ordered
            .once
          expect(scanner).to receive(:correcting_scan)
            .with(
              {
                only_testing: [
                  'AtomicBoyUITests/AtomicBoyUITests/testExample3'
                ],
                output_directory: './results-AtomicBoyUITests'
              },
              @mock_reportnamer
            )
            .and_return(false)
            .ordered
            .once
          expect(scanner).to receive(:collate_reports).twice
          expect(@mock_reportnamer).to receive(:increment).exactly(4).times
          results = scanner.scan
          expect(results).to eq(false)
        end
      end

      describe 'correcting_scan' do
        before(:each) do
          allow(Fastlane::Actions).to receive(:sh)
          allow_any_instance_of(CorrectingScanHelper).to receive(:sleep)
        end
        describe 'one testable' do
          describe 'no batches' do
            it 'calls scan once with no failures' do
              scanner = CorrectingScanHelper.new(
                xctestrun: 'path/to/fake.xctestrun',
                output_directory: '.',
                try_count: 2,
                batch_count: 2
              )
              expect(Fastlane::Actions::ScanAction).to receive(:run).once do |config|
                expect(config._values).to have_key(:output_files)
                expect(config._values).not_to have_key(:try_count)
                expect(config._values).not_to have_key(:batch_count)
                expect(config._values).not_to have_key(:custom_report_file_name)
                expect(config._values[:output_files]).to eq('report.html,report.junit')
              end
              result = scanner.correcting_scan(
                {
                  output_directory: '.'
                },
                ReportNameHelper.new('html,junit')
              )
              expect(result).to eq(true)
            end
            it 'calls scan three times when two runs have failures' do
              scanner = CorrectingScanHelper.new(
                xctestrun: 'path/to/fake.xctestrun',
                output_directory: '.',
                try_count: 3
              )
              allow(File).to receive(:exist?).and_call_original
              allow(File).to receive(:exist?).with(%r{.*/report(-2)?.junit}).and_return(true)
              expected_report_files = ['.*/report.junit', '.*/report-2.junit']
              allow(Fastlane::Actions::TestsFromJunitAction).to receive(:run) do |config|
                expect(config._values).to have_key(:junit)
                expect(config._values[:junit]).to match(expected_report_files.shift)
                { failed: ['BagOfTests/CoinTossingUITests/testResultIsTails'] }
              end
              expect(Fastlane::Actions::ScanAction).to receive(:run).ordered.once do |config|
                expect(config._values).to have_key(:output_files)
                expect(config._values[:output_files]).to eq('report.html,report.junit')
                raise FastlaneCore::Interface::FastlaneTestFailure, 'failed tests'
              end
              expect(Fastlane::Actions::ScanAction).to receive(:run).ordered.once do |config|
                expect(config._values).to have_key(:output_files)
                expect(config._values[:output_files]).to eq('report-2.html,report-2.junit')
                raise FastlaneCore::Interface::FastlaneTestFailure, 'failed tests'
              end
              expect(Fastlane::Actions::ScanAction).to receive(:run).ordered.once do |config|
                expect(config._values).to have_key(:output_files)
                expect(config._values[:output_files]).to eq('report-3.html,report-3.junit')
                expect(config._values).to have_key(:only_testing)
                expect(config._values[:only_testing]).to eq(['BagOfTests/CoinTossingUITests/testResultIsTails'])
                raise FastlaneCore::Interface::FastlaneTestFailure, 'failed tests'
              end
              result = scanner.correcting_scan(
                {
                  output_directory: '.'
                },
                ReportNameHelper.new('html,junit')
              )
              expect(result).to eq(false)
            end

            it 'calls scan two times when there is a failure, and for the failure calls :testrun_failed_block', testrun_failed_block: true do
              actual_failure_count = 0
              scanner = CorrectingScanHelper.new(
                xctestrun: 'path/to/fake.xctestrun',
                output_directory: '.',
                try_count: 3,
                testrun_failed_block: lambda { |info|
                  actual_failure_count = info[:failed_count]
                  true
                }
              )
              allow(File).to receive(:exist?).and_call_original
              allow(File).to receive(:exist?).with(%r{.*/report(-2)?.junit}).and_return(true)
              expected_report_files = ['.*/report.junit', '.*/report-2.junit']
              allow(Fastlane::Actions::TestsFromJunitAction).to receive(:run) do |config|
                expect(config._values).to have_key(:junit)
                expect(config._values[:junit]).to match(expected_report_files.shift)
                { failed: ['BagOfTests/CoinTossingUITests/testResultIsTails'] }
              end
              expect(Fastlane::Actions::ScanAction).to receive(:run).ordered.once do |config|
                expect(config._values).to have_key(:output_files)
                expect(config._values[:output_files]).to eq('report.html,report.junit')
                raise FastlaneCore::Interface::FastlaneTestFailure, 'failed tests'
              end
              expect(Fastlane::Actions::ScanAction).to receive(:run).ordered.once do |config|
                expect(config._values).to have_key(:output_files)
                expect(config._values[:output_files]).to eq('report-2.html,report-2.junit')
              end
              result = scanner.correcting_scan(
                {
                  output_directory: '.'
                },
                ReportNameHelper.new('html,junit')
              )
              expect(actual_failure_count).to eq(1)
              expect(result).to eq(true)
            end
          end
        end
      end
    end
  end
end
