require_relative '../stream/events'
require_relative './partial_json_parser'

module LLMs
  module Parsers
    class AnthropicChatResponseStreamParser
      include PartialJsonParser

      def initialize(emitter)
        @emitter = emitter
        @received_jsons = []

        # Message metadata
        @id = nil
        @type = nil
        @role = nil
        @model = nil
        @content = []
        @stop_reason = nil
        @stop_sequence = nil
        @usage = nil
      end

      def full_response
        {
          'id' => @id,
          'type' => @type,
          'role' => @role,
          'model' => @model,
          'content' => @content,
          'stop_reason' => @stop_reason,
          'stop_sequence' => @stop_sequence,
          'usage' => @usage
        }
      end

      def handle_json(json)
        @received_jsons << json

        case json['type']
        when 'message_start'
          handle_message_start(json['message'])
        when 'content_block_start'
          handle_content_block_start(json)
        when 'content_block_delta'
          handle_content_block_delta(json)
        when 'content_block_stop'
          handle_content_block_stop(json)
        when 'message_delta'
          handle_message_delta(json)
        when 'message_stop'
          handle_message_stop
        end
      end

      private

      def handle_message_start(message)
        @id = message['id']
        @type = message['type']
        @role = message['role']
        @model = message['model']
        @content = message['content'].dup
        @usage = message['usage'].dup
        @emitter.emit(:message_started, Stream::Events::MessageStarted.new(@id))
        @emitter.emit(:usage_updated, Stream::Events::UsageUpdated.new(@id, @usage))
      end

      def handle_content_block_start(json)
        index = json['index']
        block = json['content_block'].dup
        @content[index] = block

        if block['type'] == 'text' && block['text'] && !block['text'].empty?
          ## May never happen, but just in case
          @emitter.emit(:text_delta, Stream::Events::TextDelta.new(block['text']))

        elsif block['type'] == 'tool_use'
          @emitter.emit(:tool_call_started, Stream::Events::ToolCallStarted.new(
            @id,
            block['id'],
            index,
            block['name'],
            block['input'].dup
          ))
        end
      end

      def handle_content_block_delta(json)
        index = json['index']
        current_block = @content[index]

        case json['delta']['type']
        when 'text_delta'
          text = json['delta']['text']
          current_block['text'] ||= ''
          current_block['text'] << text
          @emitter.emit(:text_delta, Stream::Events::TextDelta.new(@id, text))

        when 'input_json_delta'
          if current_block['type'] == 'tool_use'
            handle_tool_use_delta(index, json['delta']['partial_json'])
          end
        end
      end

      def handle_tool_use_delta(index, partial_json)
        current_block = @content[index]

        if current_block['input'] == {}
          current_block['input'] = ''
        end
        current_block['input'] << partial_json # This is an empty string first time

        @emitter.emit(:tool_call_arguments_json_delta, Stream::Events::ToolCallArgumentsJsonDelta.new(
          @id,
          current_block['id'],
          index,
          partial_json
        ))

        parsed, _ = attempt_parse_json(current_block['input'])
        if parsed
          @emitter.emit(:tool_call_arguments_updated, Stream::Events::ToolCallArgumentsUpdated.new(
            @id,
            current_block['id'],
            index,
            parsed
          ))
        end
      end

      def handle_content_block_stop(json)
        index = json['index']
        current_block = @content[index]

        if current_block['type'] == 'tool_use'
          parse_tool_use_input(index)

          @emitter.emit(:tool_call_completed, Stream::Events::ToolCallCompleted.new(
            @id,
            current_block['id'],
            index,
            current_block['name'],
            current_block['input']
          ))
        end
      end

      def handle_message_stop
        @emitter.emit(:message_completed, Stream::Events::MessageCompleted.new(@id, full_response))
      end

      def parse_tool_use_input(index)
        input = @content[index]['input'].to_s.strip
        @content[index]['input'] = input.empty? ? {} : JSON.parse(input)
      end

      def handle_message_delta(json)
        @stop_reason = json['delta']['stop_reason']
        @stop_sequence = json['delta']['stop_sequence']
        update_usage(json['usage']) if json['usage']
        @emitter.emit(:usage_updated, Stream::Events::UsageUpdated.new(@id, @usage))
      end

      def update_usage(usage)
        usage.each do |key, value|
          @usage[key] = value
        end
      end

    end
  end
end
