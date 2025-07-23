require_relative 'conversation_tool_call'
require_relative 'conversation_tool_result'

module LLMs
  class ConversationMessage
    USER_ROLE = 'user'
    ASSISTANT_ROLE = 'assistant'
    SYSTEM_ROLE = 'system'

    attr_reader :role, :parts, :tool_calls, :tool_results

    def initialize(role, content, tool_calls = nil, tool_results = nil)
      raise "role (#{role}) is not one of the allowed values" unless role == USER_ROLE || role == ASSISTANT_ROLE || role == SYSTEM_ROLE
      @role = role
      @parts = if content.is_a?(String)
        [{ text: content }]
      elsif content.is_a?(Array)
        content
      else
        raise "content (#{content}) is not a String or Array" ##@@ TODO validate structure of parts
      end
      @tool_calls = tool_calls
      @tool_results = tool_results
    end

    def text
      if !@parts.nil?
        text_parts = @parts.map{ |part| part[:text] }.compact
        if !text_parts.empty?
          text_parts.join
        end
      end
    end

    def images
      if !@parts.nil?
        @parts.map{ |part| part[:image] }.compact
      end
    end

    def empty?
      (@parts.nil? || @parts.empty? || self.text.nil? || self.text.empty?) &&
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
  end
end 