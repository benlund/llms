module LLMs
  module Models
    class Model
      attr_reader :model_name, :provider, :pricing, :supports_tools, :supports_vision, :supports_thinking, :enabled

      # nil for capabailities means unknown / unspecified - code will assume true for all capabilities in that case @@ TODO check this
      def initialize(model_name, provider, pricing: nil, supports_tools: nil, supports_vision: nil, supports_thinking: nil, enabled: nil)
        @model_name = model_name.to_s
        @provider = provider
        @pricing = pricing&.transform_keys(&:to_sym)
        @supports_tools = supports_tools
        @supports_vision = supports_vision
        @supports_thinking = supports_thinking
        @enabled = enabled
      end

      def full_name
        "#{@provider.provider_name}:#{@model_name}"
      end

      def possibly_supports_tools?
        @provider.possibly_supports_tools? && (@supports_tools != false)
      end

      def certainly_supports_tools?
        (
          @provider.certainly_supports_tools? && (@supports_tools != false)
        ) || (
          @provider.possibly_supports_tools? && (@supports_tools == true)
        )
      end

      def possibly_supports_vision?
        @provider.possibly_supports_vision? && (@supports_vision != false)
      end

      def certainly_supports_vision?
        (
          @provider.certainly_supports_vision? && (@supports_vision != false)
        ) || (
          @provider.possibly_supports_vision? && (@supports_vision == true)
        )
      end

      def possibly_supports_thinking?
        @provider.possibly_supports_thinking? && (@supports_thinking != false)
      end

      def certainly_supports_thinking?
        (
          @provider.certainly_supports_thinking? && (@supports_thinking != false)
        ) || (
          @provider.possibly_supports_thinking? && (@supports_thinking == true)
        )
      end

      def is_enabled?
        @provider.is_enabled? && (@enabled != false)
      end

      ##@@ TODO fix this
      def latest?
        @pricing[:latest] == true
      end

      ## TODO check everything using this
      def calculate_cost(input_tokens, output_tokens, cache_read_tokens = 0, cache_write_tokens = 0)
        return 0.0 if @pricing.empty?

        cost = 0.0
        
        if input_tokens && input_tokens > 0 && @pricing[:input]
          cost += (input_tokens / 1_000_000.0) * @pricing[:input]
        end
        
        if output_tokens && output_tokens > 0 && @pricing[:output]
          cost += (output_tokens / 1_000_000.0) * @pricing[:output]
        end
        
        if cache_read_tokens && cache_read_tokens > 0 && @pricing[:cache_read]
          cost += (cache_read_tokens / 1_000_000.0) * @pricing[:cache_read]
        end
        
        if cache_write_tokens && cache_write_tokens > 0 && @pricing[:cache_write]
          cost += (cache_write_tokens / 1_000_000.0) * @pricing[:cache_write]
        end
        
        cost
      end

    end
  end
end 