
module FixedCopyLogarchiveFastlaneSimulator
  def self.included(base)
    @@log_collection_start_time = DateTime.now
    base.instance_eval do
      def copy_logarchive(device, log_identity, logs_destination_dir)
        require 'shellwords'
        FastlaneCore::UI.verbose("> FixedCopyLogarchiveFastlaneSimulator.copy_logarchive")
        logarchive_dst = File.join(logs_destination_dir, "system_logs-#{log_identity}.logarchive")
        FileUtils.rm_rf(logarchive_dst)
        FileUtils.mkdir_p(File.expand_path("..", logarchive_dst))

        logs_collection_start = @@log_collection_start_time.strftime('%Y-%m-%d %H:%M:%S')
        command = "xcrun simctl spawn #{device.udid} log collect "
        command << "--start '#{logs_collection_start}' "
        command << "--output #{logarchive_dst.shellescape} 2>/dev/null"
        FastlaneCore::CommandExecutor.execute(command: command, print_all: false, print_command: true)
      end
    end
  end
end
