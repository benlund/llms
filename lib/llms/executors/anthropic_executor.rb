require_relative './base_executor'
require_relative '../adapters/anthropic_message_adapter'
require_relative '../parsers/anthropic_chat_response_stream_parser'
require_relative '../stream/event_emitter'
require 'anthropic'

module LLMs
  module Executors
    class AnthropicExecutor < BaseExecutor

      def execute_conversation(conversation, &block)
        if block_given?
          stream_conversation(conversation) do |handler|
            handler.on(:text_delta) do |event|
              yield event.text
            end
            ## TODO configure whether to yield thinking deltas
            handler.on(:thinking_delta) do |event|
              yield event.thinking
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
        rescue Faraday::BadRequestError => e
          @last_error = e.response[:body]
          return nil
        end
        execution_time = Time.now - start_time

        api_response = stream_parsed_response || http_response

        if api_response['error']
          @last_error = api_response['error']
          return nil
        end

        @last_received_message_id = LLMs::Adapters::AnthropicMessageAdapter.find_message_id(api_response)
        @last_received_message = LLMs::Adapters::AnthropicMessageAdapter.message_from_api_format(api_response)
        @last_usage_data = calculate_usage(api_response, execution_time)

        @last_received_message
      end

      def send_conversation(conversation)
        init_new_request(conversation)

        start_time = Time.now
        begin        
          http_response = client_request
        rescue Faraday::BadRequestError => e        
          @last_error = e.response[:body]
          return nil
        end
        execution_time = Time.now - start_time

        if http_response['error']
          @last_error = http_response['error']
          return nil
        end

        @last_received_message_id = LLMs::Adapters::AnthropicMessageAdapter.find_message_id(http_response)
        @last_received_message = LLMs::Adapters::AnthropicMessageAdapter.message_from_api_format(http_response)
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

        @system_prompt = conversation.system_message
        @available_tools = conversation.available_tools
        @formatted_messages = conversation.messages.map.with_index do |message, index|
          is_last_message = index == conversation.messages.size - 1
          LLMs::Adapters::AnthropicMessageAdapter.to_api_format(message, caching_enabled? && is_last_message)
        end

        # Figure out where to put the cache control param if no messages are provided
        # In reality there should always be a message, but we'll check
        if caching_enabled? && @formatted_messages.empty?
          if @available_tools && @available_tools.any?
            @available_tools.last[:cache_control] = {type: "ephemeral"}
          elsif @system_prompt && (@system_prompt.is_a?(String) || !@system_prompt[:cache_control])
            @system_prompt = {type: "text", text: @system_prompt, cache_control: {type: "ephemeral"}}
          end
        end
      end

      def request_params
        {
          messages: @formatted_messages,
          model: @model_name,
          temperature: @temperature,
        }.tap do |params|
          if @system_prompt
            params[:system] = system_param
          end
          if @max_tokens
            params[:max_tokens] = @max_tokens
          end
          ## Will override max_tokens if both are provided
          if @max_completion_tokens
            params[:max_tokens] = @max_completion_tokens
          end
          if @available_tools && @available_tools.any?
            params[:tools] = tool_schemas
          end
          if @thinking_mode
            params[:thinking] = { type: 'enabled' }.tap do |thinking_params|
              if @max_thinking_tokens
                thinking_params[:budget_tokens] = @max_thinking_tokens
              else
                # This is the minimum budget for thinking, and is required if thinking is enabled
                thinking_params[:budget_tokens] = 1024
              end
            end
          end
        end
      end

      def client_request
        @client.messages(parameters: request_params)
      end

      def stream_client_request(emitter)
        parser = Parsers::AnthropicChatResponseStreamParser.new(emitter)

        params = request_params.merge({
          stream: Proc.new do |data|
            parser.handle_json(data)
          end
        })

        [@client.messages(parameters: params), parser.full_response]
      end

      def initialize_client
        @client = Anthropic::Client.new(access_token: fetch_api_key)
      end

      ## TODO move to adapter
      def tool_schemas
        @available_tools.map do |tool|
          {
            name: tool.tool_schema[:name],
            description: tool.tool_schema[:description],
            input_schema: {
              type: 'object',
              properties: tool.tool_schema[:parameters][:properties],
              required: tool.tool_schema[:parameters][:required]
            }
          }
        end
      end

      def system_param
        @system_prompt
      end

      def calculate_usage(api_response, execution_time)
        input_tokens = nil
        output_tokens = nil
        token_counts = {}
        cache_was_written = nil
        cache_was_read = nil

        if usage = api_response['usage']
          input_tokens = 0
          output_tokens = 0
          cache_was_written = false
          cache_was_read = false

          if it = usage['input_tokens']
            input_tokens += it
            token_counts[:input] = it
          end
          
          if ccit = usage['cache_creation_input_tokens']
            input_tokens += ccit
            if ccit > 0
              cache_was_written = true
            end
          end
          
          if crit = usage['cache_read_input_tokens']
            input_tokens += crit
            token_counts[:cache_read] = crit
            if crit > 0
              cache_was_read = true
            end
          end
          
          if cache_details = usage['cache_creation']
            if it1h = cache_details['ephemeral_1h_input_tokens']
              token_counts[:cache_write_1hr] = it1h
              if it1h > 0
                cache_was_written = true
              end
            end
            if it5min = cache_details['ephemeral_5min_input_tokens']
              token_counts[:cache_write_5min] = it5min
              if it5min > 0
                cache_was_written = true
              end
            end
          elsif ccit = usage['cache_creation_input_tokens']
            # if no details, all caching is 5min
            token_counts[:cache_write_5min] = ccit
          end
          
          if ot = usage['output_tokens']
            output_tokens += ot
            token_counts[:output] = ot
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
    end
  end
end
