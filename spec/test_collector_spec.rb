RSpec.shared_context '2 testables testplan context', :shared_context => :metadata do
  before(:each) do
    allow(FastlaneCore::Configuration).to receive(:create).and_call_original
    allow(FastlaneCore::Configuration).to receive(:create)
      .with(Fastlane::Actions::TestplansFromSchemeAction.available_options, anything)
      .and_return({})

    allow(Fastlane::Actions::TestplansFromSchemeAction).to receive(:run).and_return(
      [
        './spec/fixtures/code-coverage.xctestplan'
      ]
    )
  end
end

RSpec.shared_context '1-testable only_testing_from_testplan context', :shared_context => :metadata do
  before(:each) do
    allow(TestCenter::Helper::TestCollector).to receive(:only_testing_from_testplan)
      .and_return([
        'MyTestable/MyTestSuite/testCase1',
        'MyTestable/MyTestSuite/testCase2'
      ])
  end
end

RSpec.shared_context '2-testable only_testing_from_testplan context', :shared_context => :metadata do
  before(:each) do
    allow(TestCenter::Helper::TestCollector).to receive(:only_testing_from_testplan)
      .and_return([
        'MyTestable1/MyTestSuite/testCase1',
        'MyTestable1/MyTestSuite/testCase2',
        'MyTestable2/MyTestSuite/testCase1',
        'MyTestable2/MyTestSuite/testCase2'
      ])
  end
end

RSpec.shared_context 'xctestrun_filepath context', :shared_context => :metadata do
  before(:each) do
    allow(TestCenter::Helper::TestCollector).to receive(:xctestrun_filepath).and_return('path/to/fake.xctestrun')
  end
end

RSpec.shared_context '2-testable xctestrun_known_tests context', :shared_context => :metadata do
  before(:each) do
    allow(FastlaneCore::Configuration).to receive(:create).and_call_original
    allow(FastlaneCore::Configuration).to receive(:create)
      .with(Fastlane::Actions::TestsFromXctestrunAction.available_options, anything)
      .and_return({})

    allow(Fastlane::Actions::TestsFromXctestrunAction).to receive(:run).and_return(
      {
        'MyTestable1' => [
          'MyTestable1/MyTestSuite/testCase1',
          'MyTestable1/MyTestSuite/testCase2'
        ],
        'MyTestable2' => [
          'MyTestable2/MyTestSuite/testCase1',
          'MyTestable2/MyTestSuite/testCase2'
        ]
      }
    )
  end
end

module TestCenter::Helper
  describe TestCenter do
    describe TestCenter::Helper do
      describe TestCollector do
        before (:each) do
          allow(File).to receive(:exist?).and_call_original
          allow(File).to receive(:exist?).with('path/to/fake.xctestrun').and_return(true)
        end

        describe 'xctestrun_filepath' do
          it 'throws an exception for a non-existent xctestrun file' do
            expect { TestCollector.xctestrun_filepath(xctestrun: 'path/to/non/existent.xctestrun') }.to(
              raise_error(FastlaneCore::Interface::FastlaneError) do |e|
                expect(e.message).to match(/Error: cannot find xctestrun file/)
              end
            )
          end

          it 'throws an exception for a derived_data_path that does not have an xctestrun' do
            expect { TestCollector.xctestrun_filepath(derived_data_path: 'path/to/non/derived-data') }.to(
              raise_error(FastlaneCore::Interface::FastlaneError) do |e|
                expect(e.message).to match(/Error: cannot find xctestrun file/)
              end
            )
          end

          it 'throws an exception for a project that does not have an xctestrun' do
            mock_project = OpenStruct.new
            allow(mock_project).to receive(:build_settings).and_return('path/to/non/derived-data')
            Scan.project = mock_project

            expect { TestCollector.xctestrun_filepath({}) }.to(
              raise_error(FastlaneCore::Interface::FastlaneError) do |e|
                expect(e.message).to match(/Error: cannot find xctestrun file/)
              end
            )
          end
        end

        describe 'only_testing_from_testplan' do
          include_context '2 testables testplan context'

          it 'returns expected tests' do
            tests = TestCollector.only_testing_from_testplan(testplan: 'code-coverage', scheme: 'None')
            expect(tests).to eq([
              'AtomicBoyTests/AtomicBoyTests/testExample',
              'AtomicBoyTests/AtomicBoyTests/testPerformanceExample',
              'AtomicBoyUITests/AtomicBoyUITests/testExample',
              'AtomicBoyUITests/AtomicBoyUITests/testExample2',
              'AtomicBoyUITests/AtomicBoyUITests/testExample3'
            ])
          end
        end

        describe 'batches' do
          describe 'batch_count: 1' do
            describe 'xctestrun file with 2 testables' do
              include_context '2-testable xctestrun_known_tests context'

              it 'creates 2 batches' do
                tc = TestCollector.new(
                  scheme: 'None',
                  xctestrun: './spec/fixtures/fake.xctestrun'
                )
                expect(tc.batches.size).to eq(2)
                expect(tc.testables).to eq(
                  ['MyTestable1', 'MyTestable2']
                )
              end

              describe 'parallel_testrun_count of 2' do
                it 'creates 4 batches' do
                  tc = TestCollector.new(
                    scheme: 'None',
                    xctestrun: './spec/fixtures/fake.xctestrun',
                    parallel_testrun_count: 2
                  )
                  expect(tc.batches.size).to eq(4)
                  expect(tc.testables).to eq(
                    ['MyTestable1', 'MyTestable2']
                  )
                end
              end

              describe 'skip_testing' do
                it 'creates 2 batches without skipped tests' do
                  tc = TestCollector.new(
                    scheme: 'None',
                    xctestrun: './spec/fixtures/fake.xctestrun',
                    skip_testing: [
                      'MyTestable1/MyTestSuite/testCase2',
                      'MyTestable2/MyTestSuite/testCase1'
                    ]
                  )
                  expect(tc.batches).to eq(
                    [
                      ['MyTestable1/MyTestSuite/testCase1'],
                      ['MyTestable2/MyTestSuite/testCase2']
                    ]
                  )
                  expect(tc.testables).to eq(
                    ['MyTestable1', 'MyTestable2']
                  )
                end
              end
            end

            describe 'only_testing' do
              include_context 'xctestrun_filepath context'
              include_context '2-testable xctestrun_known_tests context'

              describe '1 testable' do
                it 'creates 1 batch' do
                  tc = TestCollector.new(
                    only_testing: [
                      'MyTestable1/MyTestSuite/testCase1',
                      'MyTestable1/MyTestSuite/testCase2'
                    ],
                    scheme: 'None'
                  )
                  expect(tc.batches.size).to eq(1)
                end

                it 'expands a testable to all the tests' do
                  tc = TestCollector.new(
                    only_testing: [
                      'MyTestable1'
                    ],
                    scheme: 'None'
                  )
                  expect(tc.batches[0].size).to eq(2)
                  expect(tc.testables).to eq(
                    ['MyTestable1']
                  )
                end
              end

              describe '2 testables' do
                it 'expands both testables to all the tests' do
                  tc = TestCollector.new(
                    only_testing: [
                      'MyTestable1',
                      'MyTestable2'
                    ],
                    scheme: 'None'
                  )
                  expect(tc.batches[0]).to eq(
                    [
                      'MyTestable1/MyTestSuite/testCase1',
                      'MyTestable1/MyTestSuite/testCase2'
                    ]
                  )
                  expect(tc.batches[1]).to eq(
                    [
                      'MyTestable2/MyTestSuite/testCase1',
                      'MyTestable2/MyTestSuite/testCase2'
                    ]
                  )
                  expect(tc.testables).to eq(
                    ['MyTestable1', 'MyTestable2']
                  )
                end
              end
            end

            describe 'with a testplan' do
              describe 'with 1 testable' do
                include_context '1-testable only_testing_from_testplan context'
                include_context 'xctestrun_filepath context'

                it 'creates 1 batch' do
                  tc = TestCollector.new(
                    testplan: 'code-coverage',
                    scheme: 'None'
                  )
                  expect(tc.batches.size).to eq(1)
                  expect(tc.testables).to eq(
                    ['MyTestable']
                  )
                end
              end

              describe 'with 2 testables' do
                include_context '2-testable only_testing_from_testplan context'
                include_context 'xctestrun_filepath context'

                it 'creates 2 batches' do
                  tc = TestCollector.new(
                    testplan: 'code-coverage',
                    scheme: 'None'
                  )
                  expect(tc.batches.size).to eq(2)
                  expect(tc.testables).to eq(
                    ['MyTestable1', 'MyTestable2']
                  )
                end
              end
            end
          end

          describe 'batch_count: 2' do
            describe 'xctestrun file with 2 testables' do
              include_context '2-testable xctestrun_known_tests context'

              it 'creates 4 batches' do
                tc = TestCollector.new(
                  scheme: 'None',
                  xctestrun: './spec/fixtures/fake.xctestrun',
                  batch_count: 2
                )
                expect(tc.batches.size).to eq(4)
                expect(tc.testables).to eq(
                  ['MyTestable1', 'MyTestable2']
                )
              end

              describe 'parallel_testrun_count of 2' do
                it 'creates 4 batches' do
                  tc = TestCollector.new(
                    scheme: 'None',
                    xctestrun: './spec/fixtures/fake.xctestrun',
                    batch_count: 2,
                    parallel_testrun_count: 2
                  )
                  expect(tc.batches.size).to eq(4)
                  expect(tc.testables).to eq(
                    ['MyTestable1', 'MyTestable2']
                  )
                end
              end

              describe 'skip_testing' do
                it 'creates 2 batches without skipped tests' do
                  tc = TestCollector.new(
                    scheme: 'None',
                    xctestrun: './spec/fixtures/fake.xctestrun',
                    skip_testing: [
                      'MyTestable2'
                    ],
                    batch_count: 2
                  )
                  expect(tc.batches).to eq(
                    [
                      ['MyTestable1/MyTestSuite/testCase1'],
                      ['MyTestable1/MyTestSuite/testCase2']
                    ]
                  )
                  expect(tc.testables).to eq(
                    ['MyTestable1']
                  )
                end

                it 'creates 0 batches without any skipped tests' do
                  tc = TestCollector.new(
                    scheme: 'None',
                    xctestrun: './spec/fixtures/fake.xctestrun',
                    skip_testing: [
                      'MyTestable1',
                      'MyTestable2'
                    ],
                    batch_count: 2
                  )

                  expect(tc.batches).to eq([])
                  expect(tc.testables).to eq([])
                end
              end
            end

            describe 'with only_testing' do
              include_context 'xctestrun_filepath context'
              include_context '2-testable xctestrun_known_tests context'

              describe 'of an array of tests for 1 testable' do
                it 'creates 2 batch' do
                  tc = TestCollector.new(
                    only_testing: [
                      'MyTestable1/MyTestSuite/testCase1',
                      'MyTestable1/MyTestSuite/testCase2'
                    ],
                    scheme: 'None',
                    batch_count: 2
                  )
                  expect(tc.batches.size).to eq(2)
                  expect(tc.testables).to eq(
                    ['MyTestable1']
                  )
                end
              end

              describe 'of a comma-separated string for 1 testable' do
                it 'creates 2 batches' do
                  tc = TestCollector.new(
                    only_testing: 'MyTestable1/MyTestSuite/testCase1, MyTestable1/MyTestSuite/testCase2',
                    scheme: 'None',
                    batch_count: 2,
                    xctestrun: './spec/fixtures/fake.xctestrun'
                  )
                  expect(tc.batches.size).to eq(2)
                  expect(tc.testables).to eq(
                    ['MyTestable1']
                  )
                end
              end

              describe 'of an array of tests for 2 testables' do
                it 'creates 4 batches' do
                  tc = TestCollector.new(
                    only_testing: [
                      'MyTestable1',
                      'MyTestable2'
                    ],
                    xctestrun: './spec/fixtures/fake.xctestrun',
                    scheme: 'None',
                    batch_count: 2
                  )
                  expect(tc.batches[0]).to eq(
                    [
                      'MyTestable1/MyTestSuite/testCase1'
                    ]
                  )
                  expect(tc.batches[1]).to eq(
                    [
                      'MyTestable1/MyTestSuite/testCase2'
                    ]
                  )
                  expect(tc.batches[2]).to eq(
                    [
                      'MyTestable2/MyTestSuite/testCase1'
                    ]
                  )
                  expect(tc.batches[3]).to eq(
                    [
                      'MyTestable2/MyTestSuite/testCase2'
                    ]
                  )
                  expect(tc.testables).to eq(
                    ['MyTestable1', 'MyTestable2']
                  )
                end
              end
            end

            describe 'with a testplan' do
              describe 'with 1 testable' do
                include_context '1-testable only_testing_from_testplan context'
                include_context 'xctestrun_filepath context'

                it 'creates 2 batch' do
                  tc = TestCollector.new(
                    testplan: 'code-coverage',
                    scheme: 'None',
                    batch_count: 2
                  )
                  expect(tc.batches.size).to eq(2)
                  expect(tc.testables).to eq(
                    ['MyTestable']
                  )
                end
              end

              describe 'with 2 testables' do
                include_context '2-testable only_testing_from_testplan context'
                include_context 'xctestrun_filepath context'

                it 'creates 4 batches' do
                  tc = TestCollector.new(
                    testplan: 'code-coverage',
                    scheme: 'None',
                    batch_count: 2
                  )
                  expect(tc.batches.size).to eq(4)
                  expect(tc.testables).to eq(
                    ['MyTestable1', 'MyTestable2']
                  )
                end
              end

            end
          end

          describe 'given batches' do
            include_context '2-testable xctestrun_known_tests context'
            include_context 'xctestrun_filepath context'

            it 'provides the given batches, regardless of other options' do
              tc = TestCollector.new(
                scheme: 'None',
                xctestrun: './spec/fixtures/fake.xctestrun',
                batches: [
                  ['MyTestable1'],
                  ['MyTestable2/MyTestSuite/testCase1'],
                  ['MyTestable2/MyTestSuite/testCase2']
                ],
                only_testing: [
                  'MyTestable1',
                  'MyTestable2'
                ],
                batch_count: 4
              )
              expect(tc.batches).to eq(
                [
                  [
                    'MyTestable1/MyTestSuite/testCase1',
                    'MyTestable1/MyTestSuite/testCase2'
                  ],
                  ['MyTestable2/MyTestSuite/testCase1'],
                  ['MyTestable2/MyTestSuite/testCase2']
                ]
              )
              expect(tc.testables).to eq(
                ['MyTestable1', 'MyTestable2']
              )
            end
          end
        end
      end
    end
  end
end
