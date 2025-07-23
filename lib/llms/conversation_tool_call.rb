module LLMs
  class ConversationToolCall
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
end 