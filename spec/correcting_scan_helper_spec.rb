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

          allow(File).to receive(:exist?).and_call_original
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

        it 'clears out test_rest bundles before calling correcting_scan' do
          allow(@mock_testcollector).to receive(:testables).and_return(['AtomicBoyTests', 'AtomicBoyUITests'])
          scanner = CorrectingScanHelper.new(
            xctestrun: 'path/to/fake.xctestrun',
            result_bundle: true,
            output_directory: '.',
            scheme: 'AtomicBoy'
          )
          allow(@mock_testcollector).to receive(:testables_tests).and_return(
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
          )

          expected_calls = []
          allow(Dir).to receive(:glob).and_call_original
          expect(Dir).to receive(:glob).with(/.*\.test_result/) do
            expected_calls << :glob
            ['./AtomicDragon.test_result']
          end
          allow(FileUtils).to receive(:rm_rf).and_call_original
          expect(FileUtils).to receive(:rm_rf).with(['./AtomicDragon.test_result']) do
            expected_calls << :rm_rf
          end
          expect(scanner).to receive(:correcting_scan).twice do
            expected_calls << :correcting_scan
          end
          scanner.scan
          expect(expected_calls).to eq([:glob, :rm_rf, :correcting_scan, :correcting_scan])
        end

        it 'scan calls correcting_scan once for one testable' do
          scanner = CorrectingScanHelper.new(
            xctestrun: 'path/to/fake.xctestrun',
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
                  'AtomicBoyTests/AtomicBoyTests/testExample2',
                  'AtomicBoyTests/AtomicBoyTests/testExample3',
                  'AtomicBoyTests/AtomicBoyTests/testExample4'
                ],
                output_directory: '.'
              },
              1,
              @mock_reportnamer
            )
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
              1,
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
              1,
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
              1,
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
              2,
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
              1,
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
              2,
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
              1,
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
              2,
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
              1,
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
              1,
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
              1,
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
              2,
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
              1,
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
              2,
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
              1,
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
              2,
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

          @mock_testcollector = OpenStruct.new
          allow(TestCenter::Helper::TestCollector).to receive(:new).and_return(@mock_testcollector)
        end
        describe 'one testable' do
          describe 'no batches' do
            before(:each) do
              allow(File).to receive(:exist?).and_call_original
              allow(File).to receive(:exist?).and_return(true)
              allow(@mock_testcollector).to receive(:testables).and_return(['AtomicBoyTests'])
            end

            it 'calls scan once with no failures' do
              scanner = CorrectingScanHelper.new(
                xctestrun: 'path/to/fake.xctestrun',
                output_directory: '.',
                try_count: 2,
                batch_count: 2,
                clean: true
              )
              expect(Fastlane::Actions::ScanAction).to receive(:run).once do |config|
                expect(config._values).to have_key(:output_files)
                expect(config._values).not_to have_key(:try_count)
                expect(config._values).not_to have_key(:batch_count)
                expect(config._values[:clean]).to be(false)
                expect(config._values).not_to have_key(:custom_report_file_name)
                expect(config._values[:output_files]).to eq('report.html,report.junit')
              end
              result = scanner.correcting_scan(
                {
                  output_directory: '.'
                },
                1,
                ReportNameHelper.new('html,junit')
              )
              expect(scanner.retry_total_count).to eq(0)
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
                1,
                ReportNameHelper.new('html,junit')
              )
              expect(scanner.retry_total_count).to eq(2)
              expect(result).to eq(false)
            end

            it 'calls scan two times when there is a failure, and for the failure calls :testrun_completed_block' do
              actualtestrun_completed_block_infos = []
              scanner = CorrectingScanHelper.new(
                xctestrun: 'path/to/fake.xctestrun',
                output_directory: '.',
                try_count: 2,
                testrun_completed_block: lambda { |info|
                  actualtestrun_completed_block_infos << info
                }
              )
              allow(File).to receive(:exist?).and_call_original
              allow(File).to receive(:exist?).with(%r{.*/report(-2)?.junit}).and_return(true)
              expected_report_files = ['.*/report.junit', '.*/report-2.junit']
              junit_results = [
                {
                  failed: ['BagOfTests/CoinTossingUITests/testResultIsTails'],
                  passing: ['BagOfTests/CoinTossingUITests/testResultIsHeads']
                },
                {
                  failed: [],
                  passing: ['BagOfTests/CoinTossingUITests/testResultIsTails']
                }
              ]
              allow(Fastlane::Actions::TestsFromJunitAction).to receive(:run) do |config|
                expect(config._values).to have_key(:junit)
                expect(config._values[:junit]).to match(expected_report_files.shift)
                junit_results.shift
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
                1,
                ReportNameHelper.new('html,junit')
              )
              expect(actualtestrun_completed_block_infos.size).to eq(2)
              expect(actualtestrun_completed_block_infos[0]).to include(
                failed: ['BagOfTests/CoinTossingUITests/testResultIsTails'],
                passing: ['BagOfTests/CoinTossingUITests/testResultIsHeads'],
                batch: 1,
                try_count: 1,
                report_filepath: "./report.junit"
              )
              expect(actualtestrun_completed_block_infos[1]).to include(
                failed: [],
                passing: ['BagOfTests/CoinTossingUITests/testResultIsTails'],
                batch: 1,
                try_count: 2,
                report_filepath: "./report-2.junit"
              )
              expect(scanner.retry_total_count).to eq(1)
              expect(result).to eq(true)
            end

            it 'calls scan three times when two runs have failures and copies the test_result bundle to a numbered bundle' do
              scanner = CorrectingScanHelper.new(
                xctestrun: 'path/to/fake.xctestrun',
                output_directory: '.',
                try_count: 3,
                result_bundle: true,
                scheme: 'AtomicBoy'
              )
              allow(File).to receive(:exist?).and_call_original
              allow(File).to receive(:exist?).with(%r{.*/report(-2)?.junit}).and_return(true)
              allow(Fastlane::Actions::TestsFromJunitAction).to receive(:run) do |config|
                { failed: ['BagOfTests/CoinTossingUITests/testResultIsTails'] }
              end
              expect(Fastlane::Actions::ScanAction).to receive(:run).ordered.once do |config|
                raise FastlaneCore::Interface::FastlaneTestFailure, 'failed tests'
              end
              expect(Fastlane::Actions::ScanAction).to receive(:run).ordered.once do |config|
                raise FastlaneCore::Interface::FastlaneTestFailure, 'failed tests'
              end
              expect(Fastlane::Actions::ScanAction).to receive(:run).ordered.once do |config|
                raise FastlaneCore::Interface::FastlaneTestFailure, 'failed tests'
              end
              expected_fileutils_mv_params_list = [
                {
                  src: './AtomicBoy.test_result',
                  dest: './AtomicBoy_0.test_result'
                },
                {
                  src: './AtomicBoy.test_result',
                  dest: './AtomicBoy_1.test_result'
                },
                {
                  src: './AtomicBoy.test_result',
                  dest: './AtomicBoy_2.test_result'
                },
                {
                  src: './AtomicBoy.test_result',
                  dest: './AtomicBoy_0.test_result'
                },
                {
                  src: './AtomicBoy.test_result',
                  dest: './AtomicBoy_1.test_result'
                },
                {
                  src: './AtomicBoy.test_result',
                  dest: './AtomicBoy_2.test_result'
                }
              ]
              expect(FileUtils).to receive(:mv) do |src, dest|
                expected_fileutils_mv_params = expected_fileutils_mv_params_list.shift
                expect(expected_fileutils_mv_params[:src]).to eq(src)
                expect(expected_fileutils_mv_params[:dest]).to eq(dest)
              end.twice
              result = scanner.correcting_scan(
                {
                  output_directory: '.',
                  scheme: 'AtomicBoy'
                },
                1,
                ReportNameHelper.new('html,junit')
              )
              expect(scanner.retry_total_count).to eq(2)
              expect(result).to eq(false)
            end
          end
        end
      end
    end
  end
end
