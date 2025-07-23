require_relative '../conversation_message'
require_relative './base_message_adapter'
require_relative './open_ai_compatible_tool_call_adapter'

module LLMs
  module Adapters
    class OpenAICompatibleMessageAdapter < BaseMessageAdapter

      def self.to_api_format(message, _caching_enabled = false)
        formatted_messages = []

        message.tool_results&.each do |tool_result|
          formatted_messages << {
            role: 'tool',
            name: tool_result.name,
            tool_call_id: tool_result.tool_call_id,
            content: tool_result.results
          }
        end

        m = {
          role: message.role
        }

        if message.system? && message.text
          m[:content] = message.text
        else
          has_images = message.parts&.any? { |part| part[:image] }
          
          if has_images
            m[:content] = []
            message.parts&.each do |part|
              if part[:text]
                m[:content] << {type: 'text', text: part[:text]}
              end

              if part[:image]
                m[:content] << {type: 'image_url', image_url: {url: "data:#{part[:media_type] || 'image/png'};base64,#{part[:image]}"}}
              end
            end
          else
            ## TODO check this
            # For text-only messages, use array format to match test expectations
            m[:content] = [{type: 'text', text: message.text}]
          end
        end

        message.tool_calls&.each do |tool_call|
          m[:tool_calls] ||= []
          arguments = tool_call.arguments.is_a?(String) ? tool_call.arguments : JSON.dump(tool_call.arguments)
          m[:tool_calls] << {
            id: tool_call.tool_call_id,
            type: 'function',
            function: {
              name: tool_call.name,
              arguments: arguments
            }
          }
        end

        formatted_messages << m if m[:content] || m[:tool_calls]

        formatted_messages
      end

      def self.transform_tool_call(api_response_format_part, index)
        LLMs::Adapters::OpenAICompatibleToolCallAdapter.from_api_format(api_response_format_part, index)
      end

      def self.find_role(api_response_format)
        api_response_format.dig('choices', 0, 'message', 'role')
      end

      def self.find_message_id(api_response_format)
        api_response_format['id']
      end

      def self.find_text(api_response_format)
        api_response_format.dig('choices', 0, 'message', 'content')
      end

      def self.find_tool_calls(api_response_format)
        api_response_format.dig('choices', 0, 'message', 'tool_calls')
      end

    end
  end
end
