require_relative './sse_chat_response_stream_parser'
require_relative '../stream/events'

module LLMs
  module Parsers
    class GoogleGeminiChatResponseStreamParser < SSEChatResponseStreamParser

      attr_reader :current_message_id

      def full_response
        fr = {
          'candidates' => @candidates,
          'modelVersion' => @model_version,
          'usageMetadata' => @usage_metadata
        }

        pp fr

        fr
      end

      protected

      def initialize_state
        @candidates = []
        @model_version = nil
        @usage_metadata = nil
        @current_message_id = nil
        @tool_call_count = 0
      end

      def handle_json(json)
        update_candidates(json['candidates']) if json['candidates']
        update_model_version(json['modelVersion']) if json['modelVersion']
        update_usage_metadata(json['usageMetadata']) if json['usageMetadata']
      end

      private

      def update_candidates(candidates)
        candidates.each_with_index do |candidate, index|
          @candidates[index] ||= {}
          current_candidate = @candidates[index]

          if @current_message_id.nil?
            @current_message_id = "gemini-#{Time.now.to_i}"
            @emitter.emit(:message_started, Stream::Events::MessageStarted.new(@current_message_id))
          end

          if content = candidate['content']
            update_candidate_content(current_candidate, content)
          end

          if finish_reason = candidate['finishReason']
            current_candidate['finishReason'] = finish_reason
            @emitter.emit(:message_completed, Stream::Events::MessageCompleted.new(@current_message_id, full_response))
          end
        end
      end

      def update_candidate_content(current_candidate, content)
        current_candidate['content'] ||= {}

        if parts = content['parts']
          current_candidate['content']['parts'] ||= []
          current_candidate['content']['parts'] += parts

          parts.each do |part|
            if part['text']
              @emitter.emit(:text_delta, Stream::Events::TextDelta.new(@current_message_id, part['text']))
            end

            if part['functionCall']
              tool_call_id = "tool_call#{@tool_call_count}"

              @emitter.emit(:tool_call_started, Stream::Events::ToolCallStarted.new(
                              @current_message_id,
                              tool_call_id,
                              @tool_call_count,
                              part['functionCall']['name'],
                              {}
                            ))

              args = part['functionCall']['args']

              @emitter.emit(:tool_call_arguments_json_delta, Stream::Events::ToolCallArgumentsJsonDelta.new(
                              @current_message_id,
                              tool_call_id,
                              @tool_call_count,
                              JSON.dump(args)
                            ))

              @emitter.emit(:tool_call_arguments_updated, Stream::Events::ToolCallArgumentsUpdated.new(
                              @current_message_id,
                              tool_call_id,
                              @tool_call_count,
                              args
                            ))

              @emitter.emit(:tool_call_completed, Stream::Events::ToolCallCompleted.new(
                              @current_message_id,
                              tool_call_id,
                              @tool_call_count,
                              part['functionCall']['name'],
                              args
                            ))

              @tool_call_count += 1
            end
          end
        end

        if role = content['role']
          current_candidate['role'] = role
        end
      end

      def update_model_version(version)
        @model_version = version
      end

      def update_usage_metadata(metadata)
        @usage_metadata = metadata
        @emitter.emit(:usage_updated, Stream::Events::UsageUpdated.new(@current_message_id, @usage_metadata))
      end
    end
  end
end
