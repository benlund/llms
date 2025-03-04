require_relative '../conversation_message'
require_relative './base_message_adapter'
require_relative './google_gemini_tool_call_adapter'

module LLMs
  module Adapters
    class GoogleGeminiMessageAdapter < BaseMessageAdapter

      def self.to_api_format(message)
        parts = []
        ##@@ TODO order is impotant here so make sure order of results is same as order of calls- FIXME!!!
        message.tool_results&.each do |tool_result|
          parts << {functionResponse: { name: tool_result.name, response: { name: tool_result.name, content: tool_result.results}}}
        end

        message.parts&.each do |part|
          if part[:text]
            parts << {text: part[:text]}
          end
          if part[:image]
            parts << {
              inline_data: {
                mime_type: part[:media_type] || 'image/png',
                data: part[:image]
              }
            }
          end
        end


        message.tool_calls&.each do |tool_call|
          parts << {functionCall: {name: tool_call.name, args: tool_call.arguments}}
        end
        {
          role: reverse_transform_role(message.role), ##TODO also gets changed later, fix this
          parts: parts
        }
      end

      def self.transform_role(role)
        role == 'model' ? 'assistant' : role
      end

      def self.reverse_transform_role(role)
        role == 'assistant' ? 'model' : role
      end

      def self.transform_tool_call(api_response_format_part, index)
        LLMs::Adapters::GoogleGeminiToolCallAdapter.from_api_format(api_response_format_part, index)
      end

      def self.find_role(api_response_format)
        api_response_format.dig('candidates', 0, 'role') || api_response_format.dig('candidates', 0, 'content', 'role')
      end

      def self.find_message_id(api_response_format)
        nil ## no message id in the response
      end

      def self.find_text(api_response_format)
        text_parts = api_response_format.dig('candidates', 0, 'content', 'parts')&.map { |c| c['text'] }&.compact
        text_parts.nil? || text_parts.empty? ? nil : text_parts.join
      end

      def self.find_tool_calls(api_response_format)
        api_response_format.dig('candidates', 0, 'content', 'parts')&.map { |c| c['functionCall'] }&.compact
      end

    end
  end
end
