require 'json'

module LLMs
  module Parsers
    module PartialJsonParser
      def attempt_parse_json(json)
        parsed = nil
        corrected = false

        begin
          parsed = JSON.parse(json)
        rescue JSON::ParserError
          # Track unclosed delimiters
          unclosed = []
          in_string = false
          escape_next = false

          json.each_char.with_index do |char, i|
            if escape_next
              escape_next = false
              next
            end

            case char
            when '\\'
              escape_next = true
            when '"'
              unless escape_next
                if in_string
                  if unclosed.last == :quote
                    unclosed.pop
                  end
                  in_string = false
                else
                  unclosed.push(:quote)
                  in_string = true
                end
              end
            when '{'
              unclosed.push(:brace) unless in_string
            when '['
              unclosed.push(:bracket) unless in_string
            when '}'
              if !in_string && unclosed.last == :brace
                unclosed.pop
              end
            when ']'
              if !in_string && unclosed.last == :bracket
                unclosed.pop
              end
            end
          end

          # Build correction by closing delimiters in reverse order
          correction = unclosed.reverse.map do |type|
            case type
            when :quote then '"'
            when :brace then '}'
            when :bracket then ']'
            end
          end.join

          # Try parsing with correction
          begin
            corrected = true
            corrected_json = json + correction
            parsed = JSON.parse(corrected_json)
          rescue JSON::ParserError
            parsed = nil
          end
        end

        [parsed, corrected]
      end
    end
  end
end
