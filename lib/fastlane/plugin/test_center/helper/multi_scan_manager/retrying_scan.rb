require 'pry-byebug'
module TestCenter
  module Helper
    module MultiScanManager
      class RetryingScan
        def initialize(options = {})
          @options = options
          @retrying_scan_helper = RetryingScanHelper.new(options)
        end

        def run
          try_count = @options[:try_count] || 1
          begin
            valid_scan_keys = Fastlane::Actions::ScanAction.available_options.map(&:key)
            scan_options = @options.select { |k,v| valid_scan_keys.include?(k) }
            scan_options.each do |k,v|
              Scan.config.set(k,v)
            end
            # TODO: Investigate the following error:
            """
            2019-05-09 13:32:40.707 xcodebuild[78535:1944070] [MT] DVTAssertions: Warning in /Library/Caches/com.apple.xbs/Sources/IDEFrameworks_Fall2018/IDEFrameworks-14460.46/IDEFoundation/ProjectModel/ActionRecords/IDESchemeActionTestAttachment.m:186
            Details:  Error writing attachment data to file /Users/lyndsey.ferguson/Library/Developer/Xcode/DerivedData/AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr/Logs/Test/Test-Transient Testing-2019.05.09_13-32-08--0400.xcresult/1_Test/Attachments/Screenshot_E0AE7940-E7F4-4CA8-BB2B-8822D730D10F.jpg: Error Domain=NSCocoaErrorDomain Code=4 \"The folder “Screenshot_E0AE7940-E7F4-4CA8-BB2B-8822D730D10F.jpg” doesn’t exist.\" UserInfo={NSFilePath=/Users/lyndsey.ferguson/Library/Developer/Xcode/DerivedData/AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr/Logs/Test/Test-Transient Testing-2019.05.09_13-32-08--0400.xcresult/1_Test/Attachments/Screenshot_E0AE7940-E7F4-4CA8-BB2B-8822D730D10F.jpg, NSUserStringVariant=Folder, NSUnderlyingError=0x7fa6ef34ef90 {Error Domain=NSPOSIXErrorDomain Code=2 \"No such file or directory\"}}
            Object:   <IDESchemeActionTestAttachment: 0x7fa6ef22d270>
            Method:   -_savePayload:
            Thread:   <NSThread: 0x7fa6ea516110>{number = 1, name = main}
            Please file a bug at https://bugreport.apple.com with this warning message and any useful information you can provide.

            It may be due to:
            2019-05-09 14:17:30.933 xcodebuild[86893:2045058]  IDETestOperationsObserverDebug: Failed to move logarchive from /Users/lyndsey.ferguson/Library/Developer/CoreSimulator/Devices/0D312041-2D60-4221-94CC-3B0040154D74/data/tmp/test-session-systemlogs-2019.05.09_14-17-04--0400.logarchive to diagnostics location /Users/lyndsey.ferguson/Library/Developer/Xcode/DerivedData/AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr/Logs/Test/Test-Transient Testing-2019.05.09_14-17-04--0400.xcresult/1_Test/Diagnostics/iPhone 5s_0D312041-2D60-4221-94CC-3B0040154D74/test-session-systemlogs-2019.05.09_14-17-04--0400.logarchive: Error Domain=NSCocoaErrorDomain Code=4 \"“test-session-systemlogs-2019.05.09_14-17-04--0400.logarchive” couldn’t be moved to “iPhone 5s_0D312041-2D60-4221-94CC-3B0040154D74” because either the former doesn’t exist, or the folder containing the latter doesn’t exist.\" UserInfo={NSSourceFilePathErrorKey=/Users/lyndsey.ferguson/Library/Developer/CoreSimulator/Devices/0D312041-2D60-4221-94CC-3B0040154D74/data/tmp/test-session-systemlogs-2019.05.09_14-17-04--0400.logarchive, NSUserStringVariant=(
              Move
              ), NSDestinationFilePath=/Users/lyndsey.ferguson/Library/Developer/Xcode/DerivedData/AtomicBoy-flqqvvvzbouqymbyffgdbtjoiufr/Logs/Test/Test-Transient Testing-2019.05.09_14-17-04--0400.xcresult/1_Test/Diagnostics/iPhone 5s_0D312041-2D60-4221-94CC-3B0040154D74/test-session-systemlogs-2019.05.09_14-17-04--0400.logarchive, NSFilePath=/Users/lyndsey.ferguson/Library/Developer/CoreSimulator/Devices/0D312041-2D60-4221-94CC-3B0040154D74/data/tmp/test-session-systemlogs-2019.05.09_14-17-04--0400.logarchive, NSUnderlyingError=0x7fdf96c6de90 {Error Domain=NSPOSIXErrorDomain Code=2 \"No such file or directory\"}}

            """
            Scan::Runner.new.run
            @retrying_scan_helper.after_testrun
            true
          rescue FastlaneCore::Interface::FastlaneTestFailure => e
            @retrying_scan_helper.after_testrun(e)
            retry if @retrying_scan_helper.testrun_count < try_count
            false
          rescue FastlaneCore::Interface::FastlaneBuildFailure => e
            @retrying_scan_helper.after_testrun(e)
            retry if @retrying_scan_helper.testrun_count < try_count
            false
          end
        end
      end
    end
  end
end
# Ug. How do I name this class?
# I want a class that retries a scan
# I want a class that controls or manages the class that retries the scan and the set up for that
# etc.
# So, the class or the realm could be:
# MultiScanManager
# MultiScanController
# ScanManager
# ScanMaster
# MultiScanMaster
# MasterScanManser
# MasterMultiScan
# I like MultiScanManager