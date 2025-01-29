require_relative '../conversation_message'

module LLMs
  module Adapters
    class AnthropicToolCallAdapter

      def self.from_api_format(api_response_format_part, index)
        LLMs::ConversationMessage::ToolCall.new(
          index,
          api_response_format_part['id'],
          api_response_format_part['type'],
          api_response_format_part['name'],
          api_response_format_part['input'],
        )
      end

    end
  end
end
  