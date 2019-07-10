module ScanHelper
  def self.print_scan_parameters(params)
    return if FastlaneCore::Helper.test?

    # :nocov:
    FastlaneCore::PrintTable.print_values(
      config: params,
      hide_keys: [:destination, :slack_url],
      title: "Summary for scan #{Fastlane::VERSION}"
    )
    # :nocov:
  end
end