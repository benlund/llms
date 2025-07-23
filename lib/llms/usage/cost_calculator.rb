module LLMs
  module Usage
    class CostCalculator
      def initialize(pricing)
        @pricing = pricing || {}
      end

      def calculate(usage_data, model = nil)
        pricing = model&.pricing || @pricing
        components = []
        total_cost = 0.0

        if usage_data.input_tokens > 0 && pricing[:input]
          cost = (usage_data.input_tokens / 1_000_000.0) * pricing[:input]
          components << {
            type: :input,
            tokens: usage_data.input_tokens,
            rate: pricing[:input],
            cost: cost
          }
          total_cost += cost
        end

        if usage_data.output_tokens > 0 && pricing[:output]
          cost = (usage_data.output_tokens / 1_000_000.0) * pricing[:output]
          components << {
            type: :output,
            tokens: usage_data.output_tokens,
            rate: pricing[:output],
            cost: cost
          }
          total_cost += cost
        end

        if usage_data.cache_read_tokens > 0 && pricing[:cache_read]
          cost = (usage_data.cache_read_tokens / 1_000_000.0) * pricing[:cache_read]
          components << {
            type: :cache_read,
            tokens: usage_data.cache_read_tokens,
            rate: pricing[:cache_read],
            cost: cost
          }
          total_cost += cost
        end

        if usage_data.cache_write_tokens > 0 && pricing[:cache_write]
          cost = (usage_data.cache_write_tokens / 1_000_000.0) * pricing[:cache_write]
          components << {
            type: :cache_write,
            tokens: usage_data.cache_write_tokens,
            rate: pricing[:cache_write],
            cost: cost
          }
          total_cost += cost
        end

        {
          total_cost: total_cost,
          components: components,
          currency: 'USD'
        }
      end

      def calculate_simple(input_tokens: 0, output_tokens: 0, cache_read_tokens: 0, cache_write_tokens: 0)
        usage_data = UsageData.new(
          input_tokens: input_tokens,
          output_tokens: output_tokens,
          cache_read_tokens: cache_read_tokens,
          cache_write_tokens: cache_write_tokens
        )
        calculate(usage_data)
      end
    end
  end
end 