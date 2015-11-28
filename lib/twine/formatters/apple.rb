module Twine
  module Formatters
    class Apple < Abstract
      FORMAT_NAME = 'apple'
      EXTENSION = '.strings'
      DEFAULT_FILE_NAME = 'Localizable.strings'

      def self.can_handle_directory?(path)
        Dir.entries(path).any? { |item| /^.+\.lproj$/.match(item) }
      end

      def default_file_name
        return DEFAULT_FILE_NAME
      end

      def determine_language_given_path(path)
        path_arr = path.split(File::SEPARATOR)
        path_arr.each do |segment|
          match = /^(.+)\.lproj$/.match(segment)
          if match
            if match[1] != "Base"
              return match[1]
            end
          end
        end

        return
      end

      def output_path_for_language(lang)
        "#{lang}.lproj"
      end

      def read_file(path, lang)
        encoding = Twine::Encoding.encoding_for_path(path)
        sep = nil
        if !encoding.respond_to?(:encode)
          # This code is not necessary in 1.9.3 and does not work as it did in 1.8.7.
          if encoding.end_with? 'LE'
            sep = "\x0a\x00"
          elsif encoding.end_with? 'BE'
            sep = "\x00\x0a"
          else
            sep = "\n"
          end
        end

        if encoding.index('UTF-16')
          mode = "rb:#{encoding}"
        else
          mode = "r:#{encoding}"
        end

        File.open(path, mode) do |f|
          last_comment = nil
          while line = (sep) ? f.gets(sep) : f.gets
            if encoding.index('UTF-16')
              if line.respond_to? :encode!
                line.encode!('UTF-8')
              else
                require 'iconv'
                line = Iconv.iconv('UTF-8', encoding, line).join
              end
            end
            match = /"((?:[^"\\]|\\.)+)"\s*=\s*"((?:[^"\\]|\\.)*)"/.match(line)
            if match
              key = match[1]
              key.gsub!('\\"', '"')
              value = match[2]
              value.gsub!('\\"', '"')
              value = iosify_substitutions(value)
              set_translation_for_key(key, lang, value)
              if last_comment
                set_comment_for_key(key, last_comment)
              end
            end
            if @options[:consume_comments]
              match = /\/\* (.*) \*\//.match(line)
              if match
                last_comment = match[1]
              else
                last_comment = nil
              end
            end
          end
        end
      end

      def format_header(lang)
        "/**\n * Apple Strings File\n * Generated by Twine #{Twine::VERSION}\n * Language: #{lang}\n */"
      end

      def format_section_header(section)
        "/********** #{section.name} **********/\n"
      end

      def key_value_pattern
        "\"%{key}\" = \"%{value}\";\n"
      end

      def format_comment(row, lang)
        "/* #{row.comment.gsub('*/', '* /')} */\n" if row.comment
      end

      def format_key(key)
        escape_quotes(key)
      end

      def format_value(value)
        escape_quotes(value)
      end
    end
  end
end
