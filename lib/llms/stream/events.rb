module LLMs
  module Stream
    class Events
      class Base
        attr_reader :timestamp
        def initialize
          @timestamp = Time.now
        end
      end

      class MessageStarted < Base
        attr_reader :message_id, :text
        def initialize(message_id, text = '')
          super()
          @message_id = message_id
          @text = text ##@@ TODO remove if this is guaranteed to be never there
        end
      end

      class UsageUpdated < Base
        attr_reader :message_id, :usage
        def initialize(message_id, usage)
          super()
          @message_id = message_id
          @usage = usage
        end
      end

      class TextDelta < Base
        attr_reader :message_id, :text
        def initialize(message_id, text)
          super()
          @message_id = message_id
          @text = text
        end
      end

      class ToolCallStarted < Base
        attr_reader :message_id, :tool_call_id, :index, :name, :arguments
        def initialize(message_id, tool_call_id, index, name, arguments)
          super()
          @message_id = message_id
          @tool_call_id = tool_call_id
          @index = index
          @name = name
          @arguments = arguments
        end
      end

      class ToolCallArgumentsJsonDelta < Base
        attr_reader :message_id, :tool_call_id, :index, :json_delta
        def initialize(message_id, tool_call_id, index, json_delta)
          super()
          @message_id = message_id
          @tool_call_id = tool_call_id
          @index = index
          @json_delta = json_delta
        end
      end

      ## Holds the current parse-attempted state of the arguments object, not a delta
      class ToolCallArgumentsUpdated < Base
        attr_reader :message_id, :tool_call_id, :index, :arguments
        def initialize(message_id, tool_call_id, index, arguments)
          super()
          @message_id = message_id
          @tool_call_id = tool_call_id
          @index = index
          @arguments = arguments
        end
      end

      class ToolCallCompleted < Base
        attr_reader :message_id, :tool_call_id, :index, :name, :arguments
        def initialize(message_id, tool_call_id, index, name, arguments)
          super()
          @message_id = message_id
          @tool_call_id = tool_call_id
          @index = index
          @name = name
          @arguments = arguments
        end
      end

      class MessageCompleted < Base
        attr_reader :message_id, :response
        def initialize(message_id, response)
          super()
          @message_id = message_id
          @response = response
        end
      end
    end
  end
end
