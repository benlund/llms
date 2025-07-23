require 'spec_helper'

RSpec.describe LLMs::Conversation do
  let(:conversation) { described_class.new }

  describe '#initialize' do
    it 'creates an empty conversation' do
      expect(conversation.messages).to be_empty
    end
  end

  describe '#set_system_message' do
    it 'sets a system message' do
      conversation.set_system_message('You are a helpful assistant.')
      expect(conversation.system_message).to eq('You are a helpful assistant.')
    end
  end

  describe '#add_conversaion_message' do
    it 'adds a message to the conversation' do
      message = LLMs::ConversationMessage.new('user', 'Hello')
      conversation.add_conversation_message(message)
      expect(conversation.messages).to include(message)
    end
  end

  describe '#add_assistant_message' do
    it 'adds an assistant message' do
      message = LLMs::ConversationMessage.new('user', 'Hello')
      conversation.add_conversation_message(message)
      conversation.add_assistant_message('Hi there!')
      expect(conversation.messages.length).to eq(2)
      expect(conversation.messages[1].role).to eq('assistant')
      expect(conversation.messages[1].text).to eq('Hi there!')
    end
  end

  describe '#add_user_message' do
    it 'adds a user message' do
      conversation.add_user_message('Hello')
      expect(conversation.messages.length).to eq(1)
      expect(conversation.messages.first.role).to eq('user')
      expect(conversation.messages.first.text).to eq('Hello')
    end
  end

  describe '#last_message' do
    it 'returns nil when no messages exist' do
      expect(conversation.last_message).to be_nil
    end

    it 'returns the last message' do
      conversation.add_user_message('Hello')
      conversation.add_assistant_message('Hi there!')
      expect(conversation.last_message.text).to eq('Hi there!')
    end
  end

  describe '#pending?' do
    it 'returns false when empty' do
      expect(conversation.pending?).to be false
    end

    it 'returns true when last message is user?' do
      conversation.add_user_message('Hello')
      expect(conversation.pending?).to be true
    end

    it 'returns false when last message is assisant?' do
      conversation.add_assistant_message('Hi there!')
      expect(conversation.pending?).to be false
    end
  end
end
