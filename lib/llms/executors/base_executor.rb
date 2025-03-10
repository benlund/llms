require_relative '../conversation'
require_relative '../models'

module LLMs
  module Executors
    class BaseExecutor

      DEFAULT_MAX_TOKENS = 4000 ## TODO!
      DEFAULT_MAX_THINKING_TOKENS = DEFAULT_MAX_TOKENS / 2 ## TODO!!
      DEFAULT_TEMPERATURE = 0.0
      DEFAULT_THINKING_LEVEL = 'low' ## TODO!!!

      attr_reader :client, :model_name, :model_info, :system_prompt, :temperature, :max_tokens, :available_tools,
                  :thinking_mode, :thinking_max_tokens, :thinking_level,
                  :last_sent_message, :last_received_message_id, :last_received_message, :last_usage_data, :last_error

      def initialize(**params)
        raise "model_name: is required" if params[:model_name].nil?
        
        @model_name = validate_model_name(params[:model_name])
        @model_info = params[:model_info] # Should include :pricing and :connection info
        @system_prompt = params[:system_prompt]
        @temperature = params[:temperature] || DEFAULT_TEMPERATURE
        @max_tokens = params[:max_tokens] || DEFAULT_MAX_TOKENS
        @available_tools = params[:tools]
        @cache_prompt = params[:cache_prompt]

        ##@@ TODO check model suports these params
        @thinking_mode = params.key?(:thinking) ? params[:thinking] : false
        @thinking_max_tokens = params.key?(:thinking_max_tokens) ? params[:thinking_max_tokens] : DEFAULT_MAX_THINKING_TOKENS
        @thinking_level = params.key?(:thinking_level) ? params[:thinking_level] : DEFAULT_THINKING_LEVEL

        @last_sent_message = nil
        @last_received_message = nil
        @last_usage_data = nil
        @last_error = nil

        initialize_client
      end

      def execute_prompt(prompt, system_prompt: nil, &block)
        conversation = LLMs::Conversation.new
        if sp = system_prompt || @system_prompt
          conversation.set_system_message(sp)
        end
        conversation.add_user_message(prompt)
        response_message = self.execute_conversation(conversation, &block)
        response_message&.text
      end

      def execute_conversation(conversation, &block)
        raise NotImplementedError, "Subclasses must implement execute_conversation"
      end

      private

      def initialize_client
        raise NotImplementedError, "Subclasses must implement initialize_client"
      end

      ## override to restrict models to a specific set
      ##@@ TODO check it is a known model
      def validate_model_name(model_name)
        model_name 
      end

      def tool_schemas
        raise NotImplementedError, "Subclasses must implement tool_schemas"
      end

      def caching_enabled?
        @cache_prompt == true
      end

      def calculate_usage(response)
        raise NotImplementedError, "Subclasses must implement calculate_usage"
      end

      def calculate_cost(input_tokens, output_tokens, cache_write_tokens = 0, cache_read_tokens = 0)
        if @model_info && @model_info[:pricing]
          cost_components = []
          cost_components << {name: "input", cost: (input_tokens.to_f / 1_000_000.0) * @model_info[:pricing][:input]}
          cost_components << {name: "output", cost: (output_tokens.to_f / 1_000_000.0) * @model_info[:pricing][:output]}
          if cache_write_tokens > 0
            raise "Cache write pricing not set" unless @model_info[:pricing][:cache_write]
            cost_components << {name: "cache_write", cost: (cache_write_tokens.to_f / 1_000_000.0) * @model_info[:pricing][:cache_write]}
          end
          if cache_read_tokens > 0
            raise "Cache read pricing not set" unless @model_info[:pricing][:cache_read]
            cost_components << {name: "cache_read", cost: (cache_read_tokens.to_f / 1_000_000.0) * @model_info[:pricing][:cache_read]}
          end
          ## TODO return detailed cost components
          cost_components.sum { |c| c[:cost] }
        end
      end

    end
  end
end
