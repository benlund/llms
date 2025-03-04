require_relative '../conversation_message'

module LLMs
  module Adapters
    class BaseMessageAdapter
      def to_api_format(message)
        raise "Not implemented"
      end

      def self.message_from_api_format(api_format)
        if self.has_message?(api_format)
          role = transform_role(find_role(api_format))
          text = transform_text(find_text(api_format))
          tool_calls = transform_tool_calls(find_tool_calls(api_format))
          LLMs::ConversationMessage.new(role, [{text: text}], tool_calls, nil) ##@@ TODO better way to handle text
        else
          nil
        end
      end

      def self.has_message?(api_format)
        ## TODO override me as needed in subclasses
        !find_role(api_format).nil?
      end

      def self.transform_role(role)
        role
      end

      def self.transform_text(text)
        text
      end

      def self.transform_tool_calls(tool_calls)
        ##@@ TODO - make nil if empty?
        tool_calls.nil? ? nil : tool_calls.map.with_index { |tool_call, index| transform_tool_call(tool_call, index) }
      end

      def self.transform_tool_call(tool_call, index)
        raise "Not implemented"
      end

      def self.find_message_id(api_format)
        raise "Not implemented"
      end

      def self.find_role(api_response_format)
        raise "Not implemented"
      end

      def self.find_text(api_response_format)
        raise "Not implemented"
      end

      def self.find_tool_calls(api_response_format)
        raise "Not implemented"
      end
    end
  end
end
