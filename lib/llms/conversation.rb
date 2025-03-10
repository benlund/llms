require_relative './conversation_message'

module LLMs
  class Conversation

    attr_reader :system_message

    def initialize
      @messages = []
      @system_message = nil
      @available_tools = nil
    end

    def pending?
      @messages.last&.user?
    end

    def set_system_message(content)
      raise "content is not a String" unless content.is_a?(String)
      @system_message = content
    end

    def set_available_tools(tools)
      @available_tools = tools
    end

    def add_user_message(content, tool_results = nil)
      if content.is_a?(LLMs::ConversationMessage)
        unless tool_results.nil?
          raise "tool_results argument not allowed when adding a ConversationMessage"
        end
        unless content.user?
          raise "message role must be 'user' when calling add_user_message with a ConversationMessage"
        end
        add_conversation_message(content)
      else
        unless tool_results.nil? || tool_results.all? { |tr| tr.is_a?(LLMs::ConversationMessage::ToolResult) }
          raise "tool_results argument must be an array of ConversationMessage::ToolResult"
        end
        add_conversation_message(LLMs::ConversationMessage.new("user", content, nil, tool_results))
      end
    end

    def add_assistant_message(content, tool_calls = nil)
      if content.is_a?(LLMs::ConversationMessage)
        unless tool_calls.nil?
          raise "tool_calls argument not allowed when adding a ConversationMessage"
        end
        unless content.assistant?
          raise "message role must be 'assistant' when calling add_assistant_message with a ConversationMessage"
        end
        add_conversation_message(content)
      else
        unless tool_calls.nil? || tool_calls.all? { |tc| tc.is_a?(LLMs::ConversationMessage::ToolCall) }
          raise "tool_calls argument must be an array of ConversationMessage::ToolCall"
        end
        add_conversation_message(LLMs::ConversationMessage.new("assistant", content, tool_calls, nil))
      end
    end

    def add_conversation_message(message)
      raise "message is not a ConversationMessage" unless message.is_a?(LLMs::ConversationMessage)
      ##@@ TODO validate message.role is correct next role
      @messages << message
    end

    def system_message
      @system_message.dup
    end

    def available_tools
      @available_tools.dup
    end

    def messages(include_system_message: false)
      m = @messages.dup
      if include_system_message && @system_message
        m.unshift(LLMs::ConversationMessage.new("system", @system_message, nil, nil))
      end
      m
    end

    ## TODO deprecate this
    def formatted_messages(adapter, caching_enabled = false)
      adapter.messages_to_api_format(@messages, caching_enabled)
    end

    def last_message
      @messages.last&.dup
    end

    def find_tool_call(tool_call_id)
      @messages.each do |message|
        message.tool_calls&.each do |tool_call|
          return tool_call if tool_call.tool_call_id == tool_call_id
        end
      end
      nil
    end

  end
end
