require 'spec_helper'

RSpec.describe LLMs::ConversationMessage do
  let(:message) { described_class.new('user', 'Hello, world!') }

  describe '#initialize' do
    it 'creates a message with role and content' do
      expect(message.role).to eq('user')
      expect(message.text).to eq('Hello, world!')
    end
  end

  describe '#user?' do
    it 'returns true for user messages' do
      user_message = described_class.new('user', 'Hello')
      expect(user_message.user?).to be true
    end

    it 'returns false for non-user messages' do
      assistant_message = described_class.new('assistant', 'Hi')
      expect(assistant_message.user?).to be false
    end
  end

  describe '#assistant?' do
    it 'returns true for assistant messages' do
      assistant_message = described_class.new('assistant', 'Hi')
      expect(assistant_message.assistant?).to be true
    end

    it 'returns false for non-assistant messages' do
      user_message = described_class.new('user', 'Hello')
      expect(user_message.assistant?).to be false
    end
  end

  describe '#system?' do
    it 'returns true for system messages' do
      system_message = described_class.new('system', 'You are a helpful assistant.')
      expect(system_message.system?).to be true
    end

    it 'returns false for non-system messages' do
      user_message = described_class.new('user', 'Hello')
      expect(user_message.system?).to be false
    end
  end
end
