require_relative './sse_chat_response_stream_parser'
require_relative '../stream/events'

module LLMs
  module Parsers
    class OpenAICompatibleChatResponseStreamParser < SSEChatResponseStreamParser

      def full_response
        # to match the format for non-streamed responses, all tool call arguments
        # must be serialized back to a JSON string
        converted_choices = @choices.map do |c|
          dup_c = c.dup
          dup_c['tool_calls']&.each do |tc|
            tc['function']['arguments'] = JSON.dump(tc['function']['arguments'])
          end
          dup_c
        end
        {
          'id' => @id,
          'model' => @model,
          # TODO I think this should be converted_choices, but providers are inconsistent in their response formats - switch to this after more testing
          'choices' => @choices, #converted_choices, 
          'usage' => @usage,
          'created' => @created
        }
      end

      protected

      def initialize_state
        @id = nil
        @model = nil
        @choices = []
        @usage = nil
        @created = nil
      end

      def handle_json(json)
        update_id(json['id']) if json['id']
        update_choices(json['choices']) if json['choices']
        update_model(json['model']) if json['model']
        update_usage(json['usage']) if json['usage']
        update_created(json['created']) if json['created']
      end

      private

      def update_id(id)
        if @id.nil?
          @id = id
          @emitter.emit(:message_started, Stream::Events::MessageStarted.new(id))
        elsif @id != id
          puts "WARNING: id mismatch: #{@id} != #{id}"
        end
      end

      def update_choices(choices)
        choices.each_with_index do |choice, index|
          @choices[index] ||= { 'message' => {} }
          current_choice = @choices[index]['message']

          if delta = choice['delta']
            update_choice_delta(current_choice, delta)
          end

          if finish_reason = choice['finish_reason']
            current_choice['finish_reason'] = finish_reason
            @emitter.emit(:message_completed, Stream::Events::MessageCompleted.new(@id, full_response))
          end
        end
      end

      def update_choice_delta(current_choice, delta)
        if role = delta['role']
          current_choice['role'] = role
        end

        if content = delta['content']
          current_choice['content'] ||= ''
          current_choice['content'] += content
          @emitter.emit(:text_delta, Stream::Events::TextDelta.new(@id, content))
        end

        if tool_calls = delta['tool_calls']
          tool_calls = [tool_calls] unless tool_calls.is_a?(Array)
          update_tool_calls(current_choice, tool_calls)
        end
      end

      def update_tool_calls(current_choice, tool_calls)
        current_choice['tool_calls'] ||= []

        tool_calls.each do |tool_call|
          tool_index = tool_call['index']

          if new_call = current_choice['tool_calls'][tool_index].nil?
            current_choice['tool_calls'][tool_index] = {
              'id' => tool_call['id'],
              'type' => tool_call['type'],
              'function' => {
                'name' => tool_call['function']['name'],
                'arguments' => '' # Not this: ( tool_call['function']['arguments'].dup ) - since some providers append anyway
              }
            }
          end

          if new_call
            @emitter.emit(:tool_call_started, Stream::Events::ToolCallStarted.new(
              @id,
              tool_call['id'],
              tool_index,
              tool_call['function']['name'],
              {}
            ))
          end

          if arguments = tool_call['function']['arguments']
            current_tool_call = current_choice['tool_calls'][tool_index]
            current_tool_call['function']['arguments'] += arguments

            @emitter.emit(:tool_call_arguments_json_delta, Stream::Events::ToolCallArgumentsJsonDelta.new(
              @id,
              current_tool_call['id'],
              tool_index,
              arguments
            ))

            ## finish_reason"=>"tool_calls" <--- this is the finish reason when all tool calls completed
            ## TODO use that instead?

            parsed, corrected = attempt_parse_json(current_tool_call['function']['arguments'])

            if parsed
              if corrected
                @emitter.emit(:tool_call_arguments_updated, Stream::Events::ToolCallArgumentsUpdated.new(
                  @id,
                  current_tool_call['id'],
                  tool_index,
                  parsed
                ))
              else
                @emitter.emit(:tool_call_completed, Stream::Events::ToolCallCompleted.new(
                  @id,
                  current_tool_call['id'],
                  tool_index,
                  tool_call['function']['name'],
                  parsed
                ))
              end
            end

          end
        end
      end

      def update_model(model)
        @model = model
      end

      def update_usage(usage)
        @usage = usage
        @emitter.emit(:usage_updated, Stream::Events::UsageUpdated.new(@id, @usage))
      end

      def update_created(created)
        @created = created
      end
    end
  end
end
