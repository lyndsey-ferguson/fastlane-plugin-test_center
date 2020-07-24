module FastlaneCore
  class DeviceManager
    class Device
      def clone
        raise 'Can only clone iOS Simulators' unless self.is_simulator
        Device.new(
          name: self.name,
          udid: `xcrun simctl clone #{self.udid} '#{self.name}'`.chomp,
          os_type: self.os_type,
          os_version: self.os_version,
          state: self.state,
          is_simulator: self.is_simulator
        )
      end

      def rename(newname)
        `xcrun simctl rename #{self.udid} '#{newname}'`
        self.name = newname
      end

      def boot
        `xcrun simctl boot #{self.udid}` unless self.state == "Booted"
      end

      def shutdown
        `xcrun simctl shutdown #{self.udid}` unless self.state == "Shutdown"
      end
    end
  end
end
