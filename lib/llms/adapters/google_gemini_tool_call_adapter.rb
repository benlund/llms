require_relative '../conversation_tool_call'

module LLMs
  module Adapters
    class GoogleGeminiToolCallAdapter

      def self.from_api_format(api_response_format_part, index)
        LLMs::ConversationToolCall.new(
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
  