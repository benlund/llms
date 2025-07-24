require 'spec_helper'

RSpec.describe LLMs::Adapters::AnthropicMessageAdapter do

  describe '.to_api_format' do
    let(:message) { LLMs::ConversationMessage.new('user', 'Hello') }

    it 'converts a single message to Anthropic format' do
      result = described_class.to_api_format(message)
      expect(result).to include(
        role: 'user',
        content: [{ type: 'text', text: 'Hello' }]
      )
    end

    it 'handles message with tool calls' do
      tool_call = double('tool_call', tool_call_id: 'call_123', name: 'get_weather', arguments: '{"city": "NYC"}')
      message_with_tools = LLMs::ConversationMessage.new('assistant', 'I will call a function')
      allow(message_with_tools).to receive(:tool_calls).and_return([tool_call])
      
      result = described_class.to_api_format(message_with_tools)
      expect(result[:content]).to include(
        {
          type: 'tool_use',
          id: 'call_123',
          name: 'get_weather',
          input: '{"city": "NYC"}'
        }
      )
    end

    it 'handles message with images' do
      message_with_image = LLMs::ConversationMessage.new('user', 'Look at this image')
      allow(message_with_image).to receive(:parts).and_return([
        { text: 'Look at this image' },
        { image: 'base64_image_data', media_type: 'image/jpeg' }
      ])
      
      result = described_class.to_api_format(message_with_image)
      expect(result[:content]).to include(
        {
          type: 'image',
          source: {
            type: 'base64',
            media_type: 'image/jpeg',
            data: 'base64_image_data'
          }
        }
      )
    end
  end

  describe '.message_from_api_format' do
    let(:api_format) do
      {
        'role' => 'assistant',
        'content' => [
          { 'type' => 'text', 'text' => 'Hello there!' }
        ]
      }
    end

    it 'converts API format to conversation message' do
      result = described_class.message_from_api_format(api_format)
      expect(result).to be_a(LLMs::ConversationMessage)
      expect(result.role).to eq('assistant')
      expect(result.parts).to eq([{ text: 'Hello there!' }])
    end

    it 'handles message with tool calls' do
      api_format_with_tools = {
        'role' => 'assistant',
        'content' => [
          { 'type' => 'text', 'text' => 'I will call a function' },
          {
            'type' => 'tool_use',
            'id' => 'call_123',
            'name' => 'get_weather',
            'input' => '{"city": "NYC"}'
          }
        ]
      }
      
      result = described_class.message_from_api_format(api_format_with_tools)
      expect(result.role).to eq('assistant')
      expect(result.parts).to eq([{ text: 'I will call a function' }])
      expect(result.tool_calls).not_to be_nil
    end

    it 'returns nil for invalid format' do
      result = described_class.message_from_api_format({})
      expect(result).to be_nil
    end
  end
end 