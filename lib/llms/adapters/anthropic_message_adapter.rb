require_relative '../conversation_message'
require_relative './base_message_adapter'
require_relative './anthropic_tool_call_adapter'

module LLMs
  module Adapters
    class AnthropicMessageAdapter < BaseMessageAdapter

      def self.to_api_format(message)
        content = []

        message.tool_results&.each do |tool_result|
          tr = {type: 'tool_result', tool_use_id: tool_result.tool_call_id, content: tool_result.results}
          if tool_result.is_error
            tr[:is_error] = true
          end
          content << tr
        end

        if message.text
          content << {type: 'text', text: message.text}
        end

        message.tool_calls&.each do |tool_call|
          content << {type: 'tool_use', id: tool_call.tool_call_id, name: tool_call.name, input: tool_call.arguments}
        end

        {
          role: message.role,
          content: content
        }
      end

      def self.transform_tool_call(api_response_format_part, index)
        LLMs::Adapters::AnthropicToolCallAdapter.from_api_format(api_response_format_part, index)
      end

      def self.find_role(api_response_format)
        api_response_format['role']
      end

      def self.find_message_id(api_response_format)
        api_response_format['id']
      end

      def self.find_text(api_response_format)
        api_response_format['content']&.map { |c| c['text'] }&.compact&.join
      end

      def self.find_tool_calls(api_response_format)
        api_response_format['content']&.select { |c| c['type'] == 'tool_use' }
      end

    end
  end
end
