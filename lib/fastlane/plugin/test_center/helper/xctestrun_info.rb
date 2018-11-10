module TestCenter
  module Helper
    require 'plist'

    class XCTestrunInfo
      def initialize(xctestrun_filepath)
        raise Errno::ENOENT, xctestrun_filepath unless File.exist?(xctestrun_filepath)

        @xctestrun = Plist.parse_xml(xctestrun_filepath)
        @xctestrun_rootpath = File.dirname(xctestrun_filepath)
      end

      def app_path_for_testable(testable)
        @xctestrun[testable].fetch('UITargetAppPath') do |_|
          @xctestrun[testable]['TestHostPath']
        end.sub('__TESTROOT__', @xctestrun_rootpath)
      end

      def app_plist_for_testable(testable)
        binary_plistfile = File.join(app_path_for_testable(testable), 'Info.plist')

        Plist.parse_binary_xml(binary_plistfile)
      end
    end
  end
end

require 'plist'

class Hash
  def save_binary_plist(filename, options = {})
    Plist::Emit.save_plist(self, filename)
    `plutil -convert binary1 \"#{filename}\"`
  end
end

module Plist
  def self.parse_binary_xml(filename)
    `plutil -convert xml1 \"#{filename}\"`
    Plist.parse_xml(filename)
  end
end