module LLMs
  class ConversationMessage
    USER_ROLE = 'user'
    ASSISTANT_ROLE = 'assistant'
    SYSTEM_ROLE = 'system'

    attr_reader :role, :text, :tool_calls, :tool_results

    def initialize(role, text, tool_calls = nil, tool_results = nil)
      raise "role is not one of the allowed values" unless role == USER_ROLE || role == ASSISTANT_ROLE || role == SYSTEM_ROLE
      @role = role
      @text = text
      @tool_calls = tool_calls
      @tool_results = tool_results
    end

    def empty?
      (@text.nil? || @text.strip.empty?) &&
        (@tool_calls.nil? || @tool_calls.empty?) &&
        (@tool_results.nil? || @tool_results.empty?)
    end

    def user?
      @role == USER_ROLE
    end

    def assistant?
      @role == ASSISTANT_ROLE
    end

    ## Only for OpenAI compatible APIs
    def system?    
      @role == SYSTEM_ROLE
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