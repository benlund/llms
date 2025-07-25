require_relative '../conversation'
require_relative '../models'
require_relative '../exceptions'

module LLMs
  module Executors
    class BaseExecutor

      DEFAULT_TEMPERATURE = 0.0

      attr_reader :client, :model_name, :base_url,
              :system_prompt, :available_tools, :temperature,
              :max_tokens, :max_completion_tokens, :max_thinking_tokens,
              :thinking_mode, :thinking_effort,
              :last_sent_message, :last_received_message_id, :last_received_message, :last_usage_data, :last_error

      def initialize(**params)
        raise LLMs::ConfigurationError, "model_name is required" if params[:model_name].nil?

        @model_name = params[:model_name]
        
        # Connection Info
        @base_url = params[:base_url]
        @api_key = params[:api_key] ## Will take precedence over an env var if present
        @api_key_env_var = params[:api_key_env_var]
        @pricing = params[:pricing]
        @exclude_params = params[:exclude_params]

        # Execution Info
        @system_prompt = params[:system_prompt]
        @temperature = validate_temperature(params[:temperature] || DEFAULT_TEMPERATURE)
        @available_tools = params[:tools]
        
        @cache_prompt = params[:cache_prompt] ## TODO caching is automatic for most models now
        
        @max_tokens = validate_positive_integer_or_nil(params[:max_tokens], "max_tokens")
        @max_completion_tokens = validate_positive_integer_or_nil(params[:max_completion_tokens], "max_completion_tokens")
        @max_thinking_tokens = validate_positive_integer_or_nil(params[:max_thinking_tokens], "max_thinking_tokens")

        @thinking_mode = params.key?(:thinking) ? params[:thinking] : false
        @thinking_effort = validate_thinking_effort(params[:thinking_effort])

        ##TODO warn if max_tokens is used instead of max_completion_tokens and model is a thinking model (or thinking is enabled)

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

      def fetch_api_key
        if @api_key
          @api_key
        elsif @api_key_env_var
          ENV[@api_key_env_var] || raise("#{@api_key_env_var} not set")
        else
          raise LLMs::ConfigurationError, "No API key provided"
        end
      end

      def initialize_client
        raise NotImplementedError, "Subclasses must implement initialize_client"
      end

      def tool_schemas
        raise NotImplementedError, "Subclasses must implement tool_schemas"
      end

      def caching_enabled?
        @cache_prompt == true ##TODO caching is automatic by default now for non-Anthropic models that support it
      end

      def calculate_usage(response)
        raise NotImplementedError, "Subclasses must implement calculate_usage"
      end

      def validate_thinking_effort(effort)
        return if effort.nil?

        if effort.to_s.in?(%w[low medium high])
          effort.to_s
        else
          raise LLMs::ConfigurationError, "Thinking effort must be a string 'low', 'medium', or 'high', got: #{effort}"
        end
      end

      def validate_temperature(temp)
        unless temp.is_a?(Numeric) && temp >= 0.0 && temp <= 2.0
          raise LLMs::ConfigurationError, "Temperature must be a number between 0.0 and 2.0, got: #{temp}"
        end
        temp
      end

      def validate_positive_integer_or_nil(tokens, name)
        unless tokens.nil? || (tokens.is_a?(Integer) && tokens > 0)
          raise LLMs::ConfigurationError, "#{name} must be a positive integer, got: #{tokens}"
        end
        tokens
      end

      def calculate_cost(token_counts)
        return nil unless @pricing
        return nil if token_counts.nil? || token_counts.empty?

        token_keys = token_counts.keys.map(&:to_s)
        pricing_keys = @pricing.keys.map(&:to_s)

        missing_keys = token_keys - pricing_keys
        ## TODO remove this special case. Is it safe to skip all missing keys if the token count is zero for them?
        unless missing_keys.empty? || (missing_keys.include?('cached_input') && token_counts[:cached_input] == 0)
          raise LLMs::CostCalculationError, "Pricing missing key: #{missing_keys.join(', ')}"
        end

        token_keys.reduce(0.0) do |sum, k|
          key = k.to_sym
          if token_counts[key] && token_counts[key] > 0 && @pricing[key]
            sum + (token_counts[key].to_f / 1_000_000.0) * @pricing[key]
          else
            sum
          end
        end
      end

    end
  end
end
