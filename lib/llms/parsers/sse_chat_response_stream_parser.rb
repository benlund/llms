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
            json = parse_line_data(data)
            handle_json(json)
          end
        end
      end

      # Override in subclasses to rescue JSON parse errors if needed for the provider (shouldn't actually be needed for any?)
      def parse_line_data(data)
        JSON.parse(data)
      end

      def handle_json(json)
        # Override in subclasses to handle JSON data
      end

      def handle_done
        # Override in subclasses if needed
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
