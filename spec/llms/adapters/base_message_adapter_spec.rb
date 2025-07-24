require 'spec_helper'

RSpec.describe LLMs::Adapters::BaseMessageAdapter do

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