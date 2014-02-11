#-*-ruby-*-

# Copyright 2012 Amazon.com, Inc. or its affiliates. All Rights
# Reserved.
# 
# Licensed under the Apache License, Version 2.0 (the "License"). You
# may not use this file except in compliance with the License. A copy
# of the License is located at
#
#   http://aws.amazon.com/apache2.0/
#
# or in the "license" file accompanying this file. This file is
# distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF
# ANY KIND, either express or implied. See the License for the
# specific language governing permissions and limitations under the
# License.

module AWS

  # Generic INI file parser/emitter.  This class supports lenient
  # reading of files that don't match the expected format; in
  # addition, it doesn't disturb the lines it does not understand when
  # writing new settings to an existing file.  For example:
  #
  #  File.open("myfile.ini") { |f| f.write <<END }
  #  [mysection]
  #  I don't conform to your expectations!
  #  aKey = aValue
  #  END
  #  AWS::INI.new("myfile.ini").
  #    write_settings("mysection", "anotherKey" => "anotherValue")
  #  File.read("myfile.ini")
  #  # returns:
  #  # [mysection]
  #  # I don't conform to your expectations!
  #  # aKey = aValue
  #  # anotherKey = anotherValue
  class INI

    attr_reader :filename
    attr_reader :default_header

    class Section

      attr_reader :name
      attr_reader :lines

      def initialize(name, lines)
        @name = name
        @lines = lines
      end

      def to_h
        @lines.inject({}) do |h, line|
          (key, value) = line.split(/\=/,2)
          h[key.strip] = value.strip if key && value
          h
        end
      end

      def write_settings(settings)
        settings_ary = settings.to_a.sort_by { |(key, value)| key }
        lines.reject! do |line|
          line =~ /^([^\=]+)\=/ &&
            settings.include?($1.strip)
        end
        @lines += settings_ary.map do |(key, value)|
          "#{key}=#{value}\n"
        end
      end

    end

    def initialize(filename, default_header = true)
        @filename = filename
        @default_header = default_header
    end 

    def [](section_name)
      get_section(section_name).to_h
    end

    def write_settings(section, settings)
      get_section(section).write_settings(settings)
      File.open(filename, "w") do |f|
        sections.each do |section|
          section.lines.each { |l| f.puts l.chomp }
        end
      end
    end

    def get_section(section_name)
      if (sections.empty? rescue true) ||
          (section = sections.find { |s| s.name == section_name }).nil?
        lines = []
        lines << "[#{section_name}]\n" unless (not default_header and section_name == "global")
        @sections ||= []
        sections << (section = Section.new(section_name, lines))
      end
      section
    end

    def sections
      @sections ||= File.open(filename) do |f|
        sections = []
        pending_section = nil
        pending_lines = []
        f.each_line do |line|
          if line =~ /^\[([^\]]*)\]\s*$/
            # line is something like [mysection], where $1 would be "mysection"
            new_section = $1

            unless pending_lines.empty?
              pending_lines.unshift "[global]" if pending_section.nil? and default_header
              sections << Section.new(pending_section || "global",
                                      pending_lines)
            end

            pending_section = new_section
            pending_lines = [line]
          else
            pending_lines << line
          end
        end
        unless pending_lines.empty?
          pending_lines.unshift "[global]" if pending_section.nil? and default_header
          sections << Section.new(pending_section || "global",
                                  pending_lines)
        end
        sections
      end
    end

  end

end
