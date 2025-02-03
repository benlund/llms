module LLMs
  module Stream
    class EventEmitter
      VALID_EVENTS = [
        :message_started,
        :usage_updated,
        :text_delta,
        :tool_call_started,
        :tool_call_arguments_json_delta,
        :tool_call_arguments_updated,
        :tool_call_completed,
        :message_completed
      ]

      def initialize
        @handlers = {}
      end

      def on(event_type, &block)
        add_handler(event_type, block)
        self
      end

      def connect(obj)
        VALID_EVENTS.each do |event_type|
          self.on(event_type) do |data|
            obj.send(event_type, data)
          end
        end
        self
      end

      def add_handler(event_type, callable)
        raise ArgumentError, "Unknown event type: #{event_type}" unless VALID_EVENTS.include?(event_type)
        @handlers[event_type] ||= []
        @handlers[event_type] << callable
      end

      def emit(event_type, data)
        raise ArgumentError, "Unknown event type: #{event_type}" unless VALID_EVENTS.include?(event_type)
        @handlers[event_type]&.each do |handler|
          handler.call(data)
        end
      end
    end
  end
end
