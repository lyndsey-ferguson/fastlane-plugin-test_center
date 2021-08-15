module TestCenter
  module Helper
    require 'fastlane_core/ui/ui.rb'

    class ReportNameHelper
      attr_reader :report_count

      def initialize(output_types = nil, output_files = nil, custom_report_file_name = nil)
        @output_types = output_types || 'xcresult'
        @output_files = output_files || custom_report_file_name
        @report_count = 0

        if @output_types && @output_files.nil?
          @output_files = @output_types.split(',').map { |type| "report.#{type}" }.join(',')
        end
        unless @output_types.include?('xcresult')
          FastlaneCore::UI.important('Scan output types missing \'xcresult\', adding it')
          @output_types = @output_types.split(',').push('xcresult').join(',')
          if @output_types.split(',').size == @output_files.split(',').size + 1
            @output_files = @output_files.split(',').push('report.xcresult').join(',')
            FastlaneCore::UI.message('As output files has one less than the new number of output types, assumming the filename for the xcresult was missing and added it')
          end
        end

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

        types = @output_types.split(',').each(&:chomp)
        files = @output_files.split(',').each(&:chomp)
        if (json_index = types.find_index('json'))
          options[:formatter] = 'xcpretty-json-formatter'
          files.delete_at(json_index)
          types.delete_at(json_index)
        end
        if (xcresult_index = types.find_index('xcresult'))
          files.delete_at(xcresult_index)
          types.delete_at(xcresult_index)
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
