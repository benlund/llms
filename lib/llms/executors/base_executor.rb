require_relative '../conversation'
require_relative '../models'

module LLMs
  module Executors
    class BaseExecutor

      DEFAULT_MAX_TOKENS = 4000 ## TODO!
      DEFAULT_TEMPERATURE = 0.0

      attr_reader :client, :model_name, :model_info, :system_prompt, :temperature, :max_tokens, :available_tools,
                  :last_sent_message, :last_received_message_id, :last_received_message, :last_usage_data, :last_error

      def initialize(model_name:, model_info: nil, system_prompt: nil, tools: nil,
                     temperature: DEFAULT_TEMPERATURE, max_tokens: DEFAULT_MAX_TOKENS)
        @model_name = validate_model_name(model_name)
        @model_info = model_info # Should include :pricing and :connection info
        @system_prompt = system_prompt
        @temperature = temperature
        @max_tokens = max_tokens
        @available_tools = tools

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
      def validate_model_name(model_name)
        model_name 
      end

      def tool_schemas
        raise NotImplementedError, "Subclasses must implement tool_schemas"
      end

      def calculate_usage(response)
        raise NotImplementedError, "Subclasses must implement calculate_usage"
      end

      def calculate_cost(input_tokens, output_tokens)
        if @model_info && @model_info[:pricing]
          input_cost = (input_tokens.to_f / 1_000_000.0) * @model_info[:pricing][:input]
          output_cost = (output_tokens.to_f / 1_000_000.0) * @model_info[:pricing][:output]
          input_cost + output_cost
        end
      end

    end
  end
end
