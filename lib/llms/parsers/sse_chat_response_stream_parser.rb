require 'json'
require_relative './partial_json_parser'

module LLMs
  module Parsers
    class SSEChatResponseStreamParser
      include PartialJsonParser

      def initialize(emitter)
        @emitter = emitter
        @buffer = ''
        initialize_state
      end

      def add_data(data)
        @buffer += data
        process_buffer
      end

      def full_response
        raise NotImplementedError, "Subclasses must implement full_response"
      end

      protected

      def initialize_state
        # Override in subclasses to initialize parser state
      end

      def process_buffer
        while line = get_next_line
          process_line(line)
        end
      end

      def process_line(line)
        if line.start_with?('data: ')
          data = line[6..-1]
          if data == '[DONE]'
            handle_done
          else
            begin
              json = JSON.parse(data)
              handle_json(json)
            rescue JSON::ParserError => e
              ##@@ TODO raise here?
              puts "Error parsing JSON: #{e.message}"
              puts "Data: #{data}"
            end
          end
        end
      end

      def handle_json(json)
        # Override in subclasses to handle JSON data
      end

      def handle_done
        # Override in subclasses if needed @@ TODO
      end

      private

      def get_next_line
        if i = @buffer.index("\n")
          line = @buffer[0...i].strip
          @buffer = @buffer[(i + 1)..-1]
          line
        end
      end
    end
  end
end
