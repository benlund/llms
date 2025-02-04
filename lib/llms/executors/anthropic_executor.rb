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
          @last_error = e.response[:body] ##@@TODO need error adapters too!!?!??
          return nil
        end
        execution_time = Time.now - start_time

        if http_response['error']
          @last_error = http_response['error'] ##@@ TODO or whole response? Adapter?
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
        @available_tools = conversation.available_tools ##@@ TODO map through an adapter here
        @formatted_messages = conversation.formatted_messages(LLMs::Adapters::AnthropicMessageAdapter)
      end

      def request_params
        {
          messages: @formatted_messages,
          model: @model_name,
          temperature: @temperature,
          max_tokens: @max_tokens
        }.tap do |params|
          if @system_prompt
            params[:system] = @system_prompt
          end
          if @available_tools && @available_tools.any?
            params[:tools] = tool_schemas
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
        raise "Anthropic API key not set" if ENV['ANTHROPIC_API_KEY'].nil?
        @client = Anthropic::Client.new(access_token: ENV['ANTHROPIC_API_KEY'])
      end

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

      def calculate_usage(api_response, execution_time)
        return unless api_response['usage']
        input_tokens = api_response['usage']['input_tokens']
        output_tokens = api_response['usage']['output_tokens']
        {
          input_tokens: input_tokens,
          output_tokens: output_tokens,
          execution_time: execution_time,
          estimated_cost: calculate_cost(input_tokens, output_tokens)
        }
      end
    end
  end
end
