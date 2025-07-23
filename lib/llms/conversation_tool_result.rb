module LLMs
  class ConversationToolResult
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