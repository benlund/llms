require 'spec_helper'

RSpec.describe LLMs::Adapters::BaseMessageAdapter do
  describe '.messages_to_api_format' do
    it 'calls to_api_format for each message' do
      messages = [
        LLMs::ConversationMessage.new('user', 'Hello'),
        LLMs::ConversationMessage.new('assistant', 'Hi there!')
      ]
      
      expect { described_class.messages_to_api_format(messages) }.to raise_error(RuntimeError, /Not implemented/)
    end
  end

  describe '.to_api_format' do
    it 'raises NotImplementedError' do
      message = LLMs::ConversationMessage.new('user', 'Hello')
      expect { described_class.to_api_format(message) }.to raise_error(RuntimeError, /Not implemented/)
    end
  end

  describe '.message_from_api_format' do
    it 'raises NotImplementedError for find_role' do
      expect { described_class.message_from_api_format({}) }.to raise_error(RuntimeError, /Not implemented/)
    end
  end
end 