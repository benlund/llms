require 'spec_helper'

RSpec.describe LLMs::Adapters::OpenAICompatibleMessageAdapter do

  describe '.to_api_format' do
    let(:message) { LLMs::ConversationMessage.new('user', 'Hello') }

    it 'converts a single message to OpenAI compatible format' do
      result = described_class.to_api_format(message)
      expect(result).to be_an(Array)
      expect(result.first).to include(
        role: 'user',
        content: [{ type: 'text', text: 'Hello' }]
      )
    end

    it 'handles message with function calls' do
      tool_call = double('tool_call', tool_call_id: 'call_123', name: 'get_weather', arguments: '{"city": "NYC"}')
      message_with_tools = LLMs::ConversationMessage.new('assistant', 'I will call a function')
      allow(message_with_tools).to receive(:tool_calls).and_return([tool_call])
      result = described_class.to_api_format(message_with_tools)
      expect(result.first).to include(
        role: 'assistant',
        content: [{ type: 'text', text: 'I will call a function' }]
      )
      expect(result.first[:tool_calls]).to include(
        {
          id: 'call_123',
          type: 'function',
          function: {
            name: 'get_weather',
            arguments: '{"city": "NYC"}'
          }
        }
      )
    end

    it 'handles system messages' do
      system_message = LLMs::ConversationMessage.new('system', 'You are a helpful assistant.')
      allow(system_message).to receive(:system?).and_return(true)
      allow(system_message).to receive(:text).and_return('You are a helpful assistant.')
      result = described_class.to_api_format(system_message)
      expect(result.first).to include(
        role: 'system',
        content: 'You are a helpful assistant.'
      )
    end
  end

  describe '.message_from_api_format' do
    let(:api_format) do
      {
        'choices' => [{
          'message' => {
            'role' => 'assistant',
            'content' => 'Hello there!'
          }
        }]
      }
    end

    it 'converts API format to conversation message' do
      result = described_class.message_from_api_format(api_format)
      expect(result).to be_a(LLMs::ConversationMessage)
      expect(result.role).to eq('assistant')
      expect(result.text).to eq('Hello there!')
    end

    it 'handles message with function calls' do
      api_format_with_function = {
        'choices' => [{
          'message' => {
            'role' => 'assistant',
            'content' => 'I will call a function',
            'tool_calls' => [{
              'id' => 'call_123',
              'type' => 'function',
              'function' => {
                'name' => 'get_weather',
                'arguments' => '{"city": "NYC"}'
              }
            }]
          }
        }]
      }
      result = described_class.message_from_api_format(api_format_with_function)
      expect(result.role).to eq('assistant')
      expect(result.text).to eq('I will call a function')
      expect(result.tool_calls).not_to be_nil
    end

    it 'returns nil for invalid format' do
      result = described_class.message_from_api_format({})
      expect(result).to be_nil
    end
  end
end 