require_relative 'base_executor'
require_relative '../apis/google_gemini_api'
require_relative '../parsers/google_gemini_chat_response_stream_parser'
require_relative '../adapters/google_gemini_message_adapter'

module LLMs
  module Executors
    class GoogleGeminiExecutor < BaseExecutor

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

        if http_response && http_response['error']
          @last_error = http_response
          return nil
        end

        response_data = stream_parsed_response || http_response

        @last_received_message = LLMs::Adapters::GoogleGeminiMessageAdapter.message_from_api_format(response_data)
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
          return nil
        end
        execution_time = Time.now - start_time

        if http_response && http_response['error']
          @last_error = http_response
          return nil
        end

        @last_received_message = LLMs::Adapters::GoogleGeminiMessageAdapter.message_from_api_format(http_response)
        if @last_received_message.nil?
          @last_error = {'error' => 'No message found in the response. Can happen with thinking models if max_tokens is too low.'}
          return nil
        end

        ## TODO do this for other adapters too???

        @last_received_message_id = "gemini-#{Time.now.to_i}" ## no message id in the response
        @last_usage_data = calculate_usage(http_response, execution_time)


        @last_received_message
      end

      private

      def init_new_request(conversation)
        @last_sent_message = conversation.last_message
        @last_received_message = nil
        @last_usage_data = nil
        @last_error = nil

        @formatted_messages = conversation.messages.map do |message|
          LLMs::Adapters::GoogleGeminiMessageAdapter.to_api_format(message)
        end

        @available_tools = conversation.available_tools
      end

      def client_request
        @client.generate_content(@model_name, @formatted_messages, request_params)
      end

      def stream_client_request(emitter)
        parser = Parsers::GoogleGeminiChatResponseStreamParser.new(emitter)

        params = request_params.merge(stream: Proc.new { |chunk| parser.add_data(chunk) })
        http_response = @client.generate_content(@model_name, @formatted_messages, params)        

        @last_received_message_id = parser.current_message_id ##no message id in the response

        [http_response, parser.full_response]
      end

      def request_params
        {
          generationConfig: {
            temperature: @temperature,
            maxOutputTokens: @max_tokens,
          }
        }.tap do |params|
          if @system_prompt
            params[:system_instruction] = { parts: [{text: @system_prompt}] }
          end
          if @available_tools && @available_tools.any?
            params[:tools] = tool_schemas
          end
        end
      end

      def tool_schemas ##@@ TODO check this with complicated tool schemas
        [
          {
            function_declarations: @available_tools.map do |tool|
              {
                name: tool.tool_schema[:name],
                description: tool.tool_schema[:description],
                parameters: tool.tool_schema[:parameters]
              }
            end
          }
        ]
      end

      def calculate_usage(response, execution_time)
        input_tokens = response['usageMetadata']['promptTokenCount']
        output_tokens = response['usageMetadata']['candidatesTokenCount']

        { 
          input_tokens: input_tokens,
          output_tokens: output_tokens,
          execution_time: execution_time,
          estimated_cost: calculate_cost(input_tokens, output_tokens)
        }
      end

      def initialize_client
        ##@@ TODO api_key_env_var = @model_info[:api_key_env_var]
        raise "Google Gemini API key not set" if ENV['GOOGLE_GEMINI_API_KEY'].nil?
        @client = LLMs::APIs::GoogleGeminiAPI.new(ENV['GOOGLE_GEMINI_API_KEY'])
      end

    end
  end
end
