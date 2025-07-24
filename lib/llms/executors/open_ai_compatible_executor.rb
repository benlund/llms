require_relative 'base_executor'
require_relative '../apis/open_ai_compatible_api'
require_relative '../parsers/open_ai_compatible_chat_response_stream_parser'
require_relative '../adapters/open_ai_compatible_message_adapter'

module LLMs
  module Executors
    class OpenAICompatibleExecutor < BaseExecutor

      def execute_conversation(conversation, &block)
        if block_given?
          stream_conversation(conversation) do |handler|
            handler.on(:text_delta) do |event|
              yield event.text
            end
          end
        else
          send_conversation(conversation)
        end
      end

      def stream_conversation(conversation)
        init_new_request(conversation)

        emitter = Stream::EventEmitter.new
        yield emitter if block_given?

        start_time = Time.now
        begin
          http_response, stream_parsed_response = stream_client_request(emitter)
        rescue StandardError => e
          @last_error = {'error' => e.message, 'backtrace' => e.backtrace}
          return nil
        end
        execution_time = Time.now - start_time

        if http_response && (http_response['error'] || http_response['errors'])
          @last_error = http_response
          return nil
        end

        response_data = stream_parsed_response || http_response

        @last_received_message_id = LLMs::Adapters::OpenAICompatibleMessageAdapter.find_message_id(response_data)
        @last_received_message = LLMs::Adapters::OpenAICompatibleMessageAdapter.message_from_api_format(response_data)
        @last_usage_data = calculate_usage(response_data, execution_time)

        @last_received_message
      end

      def send_conversation(conversation)
        init_new_request(conversation)

        start_time = Time.now
        begin
          http_response = client_request
        rescue StandardError => e
          @last_error = {'error' => e.message, 'backtrace' => e.backtrace}
          @last_usage_data = nil
          @last_received_message = nil
          return nil
        end
        execution_time = Time.now - start_time

        if http_response && (http_response['error'] || http_response['errors'])
          @last_error = http_response
          return nil
        end

        @last_received_message_id = LLMs::Adapters::OpenAICompatibleMessageAdapter.find_message_id(http_response)
        @last_received_message = LLMs::Adapters::OpenAICompatibleMessageAdapter.message_from_api_format(http_response)
        @last_usage_data = calculate_usage(http_response, execution_time)

        @last_received_message
      end

      private

      def init_new_request(conversation)
        @last_sent_message = conversation.last_message
        @last_received_message_id = nil
        @last_received_message = nil
        @last_usage_data = nil
        @last_error = nil

        # need to flatten array since adapter can return array of messages for tool results
        @formatted_messages = conversation.messages(include_system_message: true).flat_map do |message|
          LLMs::Adapters::OpenAICompatibleMessageAdapter.to_api_format(message)
        end

        @available_tools = conversation.available_tools
      end

      def client_request
        params = request_params
        params[:stream] = false
        @client.chat_completion(@model_name, @formatted_messages, params)
      end

      def stream_client_request(emitter)
        parser = Parsers::OpenAICompatibleChatResponseStreamParser.new(emitter)

        params = request_params(true).merge(stream: Proc.new { |chunk| parser.add_data(chunk) })
        http_response = @client.chat_completion(@model_name, @formatted_messages, params)

        [http_response, parser.full_response]
      end

      def request_params(is_stream = false)
        {temperature: @temperature}.tap do |params|

          if param_ok?(:max_tokens) && @max_tokens
            params[:max_tokens] = @max_tokens
          end

          ## Will override max_tokens if both are provided
          if param_ok?(:max_completion_tokens) && @max_completion_tokens
            params[:max_completion_tokens] = @max_completion_tokens
          end

          if @thinking_effort
            params[:reasoning_effort] = @thinking_effort
          end

          if @available_tools && @available_tools.any?
            params[:tools] = tool_schemas ##todo make this an adapter
          end

          if is_stream && param_ok?(:stream_options)
            params[:stream_options] = {
              include_usage: true
            }
          end
        end
      end

      def param_ok?(param_name)
        !@exclude_params&.find { |param| param.to_s == param_name.to_s }
      end

      def initialize_client
        if @base_url.nil? || @base_url.empty?
          raise "base_url required for OpenAICompatibleExecutor"
        end

        @client = LLMs::APIs::OpenAICompatibleAPI.new(fetch_api_key, @base_url)
      end

      def calculate_usage(response, execution_time)
        input_tokens = nil
        output_tokens = nil
        cache_was_written = nil
        cache_was_read = nil
        token_counts = {}

        if !response.nil? && usage = response['usage']          
          input_tokens = 0
          output_tokens = 0
          cache_was_read = false

          if pt = usage['prompt_tokens']
            input_tokens += pt
            token_counts[:input] = pt
          end

          if ptd = usage['prompt_tokens_details']
            if ct = ptd['cached_tokens']
              if ct > 0
                cache_was_read = true
              end
              token_counts[:cached_input] = ct
              token_counts[:input] -= ct ##@@ TODO is this correct?
            end
          end
          
          if ct = usage['completion_tokens']
            output_tokens += ct
            token_counts[:output] = ct
          end
        end

        {
          input_tokens: input_tokens,
          output_tokens: output_tokens,
          cache_was_written: cache_was_written,
          cache_was_read: cache_was_read,
          token_details: token_counts,
          execution_time: execution_time,
          estimated_cost: calculate_cost(token_counts)
        }
      end

      def tool_schemas
        @available_tools.map do |tool|
          {
            type: 'function',
            function: {
              name: tool.tool_schema[:name],
              description: tool.tool_schema[:description],
              parameters: tool.tool_schema[:parameters],
            }
          }
        end
      end

    end
  end
end
