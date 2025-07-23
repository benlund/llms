module LLMs
  module Usage
    class UsageData
      attr_reader :input_tokens, :output_tokens, :cache_read_tokens, 
                  :cache_write_tokens, :execution_time, :model_name

      def initialize(input_tokens: 0, output_tokens: 0, 
                     cache_read_tokens: 0, cache_write_tokens: 0,
                     execution_time: 0, model_name: nil)
        @input_tokens = input_tokens.to_i
        @output_tokens = output_tokens.to_i
        @cache_read_tokens = cache_read_tokens.to_i
        @cache_write_tokens = cache_write_tokens.to_i
        @execution_time = execution_time.to_f
        @model_name = model_name
      end

      def total_tokens
        @input_tokens + @output_tokens + @cache_read_tokens + @cache_write_tokens
      end

      def to_h
        {
          input_tokens: @input_tokens,
          output_tokens: @output_tokens,
          cache_read_tokens: @cache_read_tokens,
          cache_write_tokens: @cache_write_tokens,
          total_tokens: total_tokens,
          execution_time: @execution_time,
          model_name: @model_name
        }
      end

      def to_s
        if total_tokens == 0
          "Usage: 0 tokens () in #{@execution_time.round(2)}s"
        else
          "Usage: #{total_tokens} tokens (#{@input_tokens} input, #{@output_tokens} output" +
          "#{@cache_read_tokens > 0 ? ", #{@cache_read_tokens} cache_read" : ""}" +
          "#{@cache_write_tokens > 0 ? ", #{@cache_write_tokens} cache_write" : ""}" +
          ") in #{@execution_time.round(2)}s"
        end
      end
    end
  end
end 