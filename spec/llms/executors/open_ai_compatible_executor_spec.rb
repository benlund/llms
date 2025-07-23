require 'spec_helper'

RSpec.describe LLMs::Executors::OpenAICompatibleExecutor do
  let(:params) do
    {
      model_name: 'openai:gpt-3.5-turbo',
      pricing: { input: 1.0, output: 2.0 },
      api_key: 'fake',
      base_url: 'https://api.fake.com',
      temperature: 0.0,
      max_tokens: 1000
    }
  end

  let(:conversation) { instance_double('LLMs::Conversation', last_message: 'user message', available_tools: [], messages: [], system_message: 'system') }
  let(:api_response) { { 'usage' => { 'prompt_tokens' => 10, 'completion_tokens' => 20 } } }

  before do
    stub_const('LLMs::APIs::OpenAICompatibleAPI', Class.new do
      def initialize(api_key, base_url); end
      def chat_completion(*); { 'usage' => { 'prompt_tokens' => 10, 'completion_tokens' => 20 } } end
    end)
  end

  describe '#initialize' do
    it 'raises error if base_url is missing' do
      expect {
        described_class.new(**params.merge(base_url: nil))
      }.to raise_error(RuntimeError, /base_url required/)
    end

    it 'raises error if api_key is missing' do
      expect {
        described_class.new(**params.merge(api_key: nil))
      }.to raise_error(LLMs::ConfigurationError, /No API key provided/)
    end

    it 'initializes client if all info is present' do
      exec = described_class.new(**params)
      expect(exec.client).to be_a(LLMs::APIs::OpenAICompatibleAPI)
    end
  end

  describe '#send_conversation' do
    it 'returns a message and sets usage data' do
      exec = described_class.new(**params)
      allow(exec).to receive(:init_new_request)
      allow(exec).to receive(:client_request).and_return(api_response)
      allow(LLMs::Adapters::OpenAICompatibleMessageAdapter).to receive(:find_message_id).and_return('msgid')
      allow(LLMs::Adapters::OpenAICompatibleMessageAdapter).to receive(:message_from_api_format).and_return('assistant message')
      allow(exec).to receive(:calculate_usage).and_return({ input_tokens: 10, output_tokens: 20 })

      result = exec.send(:send_conversation, conversation)
      expect(result).to eq('assistant message')
      expect(exec.last_usage_data).to eq({ input_tokens: 10, output_tokens: 20 })
      expect(exec.last_received_message_id).to eq('msgid')
      expect(exec.last_received_message).to eq('assistant message')
    end

    it 'handles StandardError and sets last_error' do
      exec = described_class.new(**params)
      allow(exec).to receive(:init_new_request)
      allow(exec).to receive(:client_request).and_raise(StandardError.new('fail'))

      result = exec.send(:send_conversation, conversation)
      expect(result).to be_nil
      expect(exec.last_error).to include({'error' => 'fail'})
    end

    it 'handles API error in response' do
      exec = described_class.new(**params)
      allow(exec).to receive(:init_new_request)
      allow(exec).to receive(:client_request).and_return({ 'error' => 'api error' })

      result = exec.send(:send_conversation, conversation)
      expect(result).to be_nil
      expect(exec.last_error).to eq({ 'error' => 'api error' })
    end
  end
end
