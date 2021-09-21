module TestCenter
  module Helper
    require 'fastlane_core/ui/ui.rb'

    class ReportNameHelper

      ##
      # Manages the report filenames for the various types that multi_scan handles
      #
      # A xcresult file types are now required to record which tests
      # failed or passed, is always 'on', regardless of whether or
      # not the client specified that they want it or not.
      #
      # The other file types that are supported are:
      # - junit
      # - html
      # - json
      #
      # There are two major functions that an instance of this class
      # provides:
      # 1. #scan_options - will provide a Hash of key-value pairs that
      #    manage how the Scan class configures Xcode tests.
      # 2. "filename" methods that provide the "last" file name used
      #    to create a file, or the "current" file name to create the
      #    next filename
      attr_reader :report_count

      ##
      # Initializes a new instance of a ReportNameHelper with some validation
      # output_types: a string with commas that separate the different
      #   types that the ReportNameHelper supports. This can be junit
      #   json, html, xcresult. 'xcresult' is _always_ added to the
      #   list as that type is used to determine which tests to retry or
      #   not.
      #
      # output_files: a string with commas that separate the different
      #   file names that will be used for each file type. Think of this
      #   as the basename of the file.
      #
      # custom_report_file_name: a string for legacy uses of the old
      #   scan tool when only one file name was provided for junit files.
      #
      def initialize(output_types = nil, output_files = nil, custom_report_file_name = nil)
        @output_types = output_types || 'xcresult'
        @output_files = output_files || custom_report_file_name
        @report_count = 0
        ensure_xcresult_enabled
        initialize_default_output_files
        validate_output_types_files_counts_match
      end

      def ensure_xcresult_enabled
        unless @output_types.include?('xcresult')
          @output_types += ',xcresult'
          unless @output_files.nil?
            @output_files += ',report.xcresult'
          end
        end
      end

      def initialize_default_output_files
        return unless @output_files.nil?
        return if @output_types.nil?

        @output_files = @output_types.split(',').map { |type| "report.#{type}" }.join(',')
      end

      ##
      # Validates that the number of 'output_files' matches the number
      # of 'output_types' that were given. For example, if the client
      # gave us 'junit' as the types, then we should have either 0 or
      # 1 file.
      def validate_output_types_files_counts_match
        return if @output_types.nil? || @output_files.nil?

        types = @output_types.split(',').each(&:chomp)
        files = @output_files.split(',').each(&:chomp)
        unless files.size == types.size
          raise ArgumentError, "Error: count of :output_types, #{types}, does not match the output filename(s) #{files}"
        end
      end

      def numbered_filename(filename)
        if @report_count > 0
          basename = File.basename(filename, '.*')
          extension = File.extname(filename)
          filename = "#{basename}-#{@report_count + 1}#{extension}"
        end
        filename
      end

      def scan_options
        options = {}
        return options if @output_types.nil? && @output_files.nil?

        types = @output_types.split(',').each(&:chomp)
        files = @output_files.split(',').each(&:chomp)
        if (json_index = types.find_index('json'))
          options[:formatter] = 'xcpretty-json-formatter'
          files.delete_at(json_index)
          types.delete_at(json_index)
        end
        if (xcresult_index = types.find_index('xcresult'))
          types.delete_at(xcresult_index)
          files.delete_at(xcresult_index)
        end
        files.map! do |filename|
          filename.chomp
          numbered_filename(filename)
        end

        output_types = types.join(',') unless types.empty?
        output_files = files.join(',') unless files.empty?
        options.merge(
          output_types: output_types,
          output_files: output_files
        )
      end

      def includes_junit?
        @output_types.split(',').find_index('junit') != nil
      end

      def junit_last_reportname
        junit_index = @output_types.split(',').find_index('junit')
        numbered_filename(@output_files.to_s.split(',')[junit_index])
      end

      def junit_reportname(suffix = '')
        junit_index = @output_types.split(',').find_index('junit')
        report_name = @output_files.to_s.split(',')[junit_index]
        return report_name if suffix.empty?

        "#{File.basename(report_name, '.*')}-#{suffix}#{junit_filextension}"
      end

      def junit_filextension
        File.extname(junit_reportname)
      end

      def junit_fileglob
        "#{File.basename(junit_reportname, '.*')}*#{junit_filextension}"
      end

      def junit_numbered_fileglob
        "#{File.basename(junit_reportname, '.*')}-[1-9]*#{junit_filextension}"
      end

      def includes_html?
        @output_types.split(',').find_index('html') != nil
      end

      def html_last_reportname
        html_index = @output_types.split(',').find_index('html')
        numbered_filename(@output_files.to_s.split(',')[html_index])
      end

      def html_reportname(suffix = '')
        html_index = @output_types.split(',').find_index('html')
        report_name = @output_files.to_s.split(',')[html_index]
        return report_name if suffix.empty?

        "#{File.basename(report_name, '.*')}-#{suffix}#{html_filextension}"
      end

      def html_filextension
        File.extname(html_reportname)
      end

      def html_fileglob
        "#{File.basename(html_reportname, '.*')}*#{html_filextension}"
      end

      def html_numbered_fileglob
        "#{File.basename(html_reportname, '.*')}-[1-9]*#{html_filextension}"
      end

      def includes_json?
        @output_types.split(',').find_index('json') != nil
      end

      def json_last_reportname
        json_index = @output_types.split(',').find_index('json')
        numbered_filename(@output_files.to_s.split(',')[json_index])
      end

      def json_reportname(suffix = '')
        json_index = @output_types.split(',').find_index('json')
        report_name = @output_files.to_s.split(',')[json_index]
        return report_name if suffix.empty?

        "#{File.basename(report_name, '.*')}-#{suffix}#{json_filextension}"
      end

      def json_filextension
        File.extname(json_reportname)
      end

      def json_fileglob
        "#{File.basename(json_reportname, '.*')}*#{json_filextension}"
      end

      def json_numbered_fileglob
        "#{File.basename(json_reportname, '.*')}-[1-9]*#{json_filextension}"
      end

      def self.ensure_output_includes_xcresult(output_types, output_files)
        return [output_types, output_files] if includes_xcresult?(output_types) || output_types.nil?

        output_types = output_types.split(',').push('xcresult').join(',')
        if output_files
          output_files = output_files.split(',').push('report.xcresult').join(',')
        end

        [output_types, output_files]
      end

      def self.includes_xcresult?(output_types)
       return false unless ::FastlaneCore::Helper.xcode_at_least?('11.0.0')
       output_types && output_types.split(',').find_index('xcresult') != nil
      end

      def includes_xcresult?
        self.class.includes_xcresult?(@output_types)
      end

      def xcresult_last_bundlename
        xcresult_index = @output_types.split(',').find_index('xcresult')
        numbered_filename(@output_files.to_s.split(',')[xcresult_index])
      end

      def xcresult_bundlename(suffix = '')
        xcresult_index = @output_types.split(',').find_index('xcresult')
        report_name = @output_files.to_s.split(',')[xcresult_index]
        return report_name if suffix.empty?

        "#{File.basename(report_name, '.*')}-#{suffix}#{xcresult_filextension}"
      end

      def xcresult_filextension
        File.extname(xcresult_bundlename)
      end

      def xcresult_fileglob
        "#{File.basename(xcresult_bundlename, '.*')}*#{xcresult_filextension}"
      end

      def xcresult_numbered_fileglob
        "#{File.basename(xcresult_bundlename, '.*')}-[1-9]*#{xcresult_filextension}"
      end

      def increment
        @report_count += 1
      end
    end
  end
end
