module LLMs
  class ConversationMessage
    attr_reader :role, :text, :tool_calls, :tool_results

    def initialize(role, text, tool_calls = nil, tool_results = nil)
      @role = role
      @text = text
      @tool_calls = tool_calls
      @tool_results = tool_results
    end

    class ToolCall
      attr_reader :index, :tool_call_id, :tool_call_type, :name, :arguments

      def initialize(index, tool_call_id, tool_call_type, name, arguments)
        raise "index is nil" if index.nil?
        @index = index
        @tool_call_id = tool_call_id
        @tool_call_type = tool_call_type
        @name = name
        @arguments = arguments
      end
    end

    class ToolResult
      attr_reader :index, :tool_call_id, :tool_call_type, :name, :results, :is_error

      def initialize(index, tool_call_id, tool_call_type, name, results, is_error)
        raise "index is nil" if index.nil?
        @index = index
        @tool_call_id = tool_call_id
        @tool_call_type = tool_call_type
        @name = name
        @results = results
        @is_error = is_error
      end
    end
  end
end 