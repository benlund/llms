require_relative '../conversation_message'

module LLMs
  module Adapters
    class OpenAICompatibleToolCallAdapter

      def self.from_api_format(api_response_format_part, index)
        name = api_response_format_part.dig('function', 'name')
        arguments_value = api_response_format_part.dig('function', 'arguments')

        if work_around_arguments_value = hyperbolic_workaround(arguments_value)
          function_value = work_around_arguments_value['function']
          name = function_value['_name']
          function_value.delete('_name')
          arguments_value = function_value
        end

        if arguments_value.nil?
          {} ##@@ TODO Check this is correct

        elsif arguments_value.is_a?(String)
          arguments = JSON.parse(arguments_value)

        # Hyperbolic returns a hash (in correct format) in non-streaming mode
        elsif arguments_value.is_a?(Hash)
          arguments = arguments_value

        else
          raise "Unexpected arguments value: #{arguments_value}"
        end

        # Some endpoints (Together at least?) return nested JSON strings that need parsing
        arguments.each do |key, value|
          if value.is_a?(String) && ( (value.start_with?('{') && value.end_with?('}')) || ((value.start_with?('[') && value.end_with?(']'))) )
            begin
              arguments[key] = JSON.parse(value)
            rescue JSON::ParserError
              # If it's not valid JSON, keep the original string
            end
          end
        end

        LLMs::ConversationMessage::ToolCall.new(
          index,
          api_response_format_part['id'],
          api_response_format_part['type'],
          name,
          arguments,
        )
      end

      ## Work around for Hyperbolic bugs:
      ## 1. In streaming mode Hyperbolic returns an arguments string that ends with '<|im_end|>'
      ## 2. In streming mode, the function name is null, and the arguments JSON has an additional nested level with _name key and arguments key
      ## 3. In non-streaming mode Hyperbolic returns an arguments hash, not a JSON parsable string (but we deal with that above)
      ## Returns a hash with the parsed arguments (in uncorrected Hyperbolic format) if they are detected, otherwise nil
      def self.hyperbolic_workaround(arguments_value)
        if arguments_value.is_a?(String) && arguments_value.end_with?('<|im_end|>')
          JSON.parse(arguments_value[0..-11])
        else
          nil
        end
      end

    end
  end
end
