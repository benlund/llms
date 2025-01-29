require_relative '../conversation_message'

module LLMs
  module Adapters
    class GoogleGeminiToolCallAdapter

      def self.from_api_format(api_response_format_part, index)
        LLMs::ConversationMessage::ToolCall.new(
          index,
          nil,
          nil,
          api_response_format_part['name'],
          api_response_format_part['args'],
        )
      end

    end
  end
end
  