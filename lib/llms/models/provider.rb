module LLMs
  module Models
    class Provider
      attr_reader :provider_name, :executor_class_name, :base_url, :api_key_env_var, :supports_tools, :supports_vision, :supports_thinking, :enabled, :exclude_params

      def initialize(provider_name, executor_class_name, base_url: nil, api_key_env_var: nil, supports_tools: nil, supports_vision: nil, supports_thinking: nil, enabled: nil, exclude_params: nil)
        @provider_name = provider_name.to_s
        @executor_class_name = executor_class_name.to_s
        @base_url = base_url
        @api_key_env_var = api_key_env_var
        @supports_tools = supports_tools
        @supports_vision = supports_vision
        @supports_thinking = supports_thinking
        @enabled = enabled
        @exclude_params = exclude_params
      end

      def possibly_supports_tools?
        @supports_tools != false
      end

      def certainly_supports_tools?
        @supports_tools == true
      end

      def possibly_supports_vision?
        @supports_vision != false
      end

      def certainly_supports_vision?
        @supports_vision == true
      end

      def possibly_supports_thinking?
        @supports_thinking != false
      end

      def certainly_supports_thinking?
        @supports_thinking == true
      end

      def is_enabled?
        @enabled != false
      end

    end
  end
end