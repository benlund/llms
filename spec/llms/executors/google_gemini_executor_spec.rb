require 'spec_helper'

RSpec.describe LLMs::Executors::GoogleGeminiExecutor do
  let(:params) do
    {
      model_name: 'gemini-1.5-pro',
      pricing: { input: 3.5, output: 10.5 },
      temperature: 0.0,
      max_tokens: 1000,
      api_key_env_var: 'GOOGLE_GEMINI_API_KEY'
    }
  end

  let(:conversation) { instance_double('LLMs::Conversation', last_message: 'user message', messages: [], available_tools: []) }
  let(:api_response) do
    {
      'candidates' => [{
        'content' => {
          'parts' => [{ 'text' => 'Hello there!' }]
        }
      }],
      'usageMetadata' => {
        'promptTokenCount' => 10,
        'candidatesTokenCount' => 5,
        'totalTokenCount' => 15
      }
    }
  end

  before do
    stub_const('LLMs::APIs::GoogleGeminiAPI', Class.new do
      def initialize(api_key); end
      def generate_content(model, messages, params); end
    end)
    allow(ENV).to receive(:[]).with('GOOGLE_GEMINI_API_KEY').and_return('fake-key')
  end

  describe '#initialize' do
    it 'raises error if API key is not set' do
      allow(ENV).to receive(:[]).with('GOOGLE_GEMINI_API_KEY').and_return(nil)
      expect {
        described_class.new(**params)
      }.to raise_error(StandardError, /GOOGLE_GEMINI_API_KEY/)
    end

    it 'initializes client if API key is set' do
      exec = described_class.new(**params)
      expect(exec.client).to be_a(LLMs::APIs::GoogleGeminiAPI)
    end
  end

  describe '#send_conversation' do
    it 'returns a message and sets usage data' do
      exec = described_class.new(**params)
      allow(exec).to receive(:init_new_request)
      allow(exec).to receive(:client_request).and_return(api_response)
      allow(LLMs::Adapters::GoogleGeminiMessageAdapter).to receive(:message_from_api_format).and_return('assistant message')
      allow(exec).to receive(:calculate_usage).and_return({ input_tokens: 10, output_tokens: 5 })

      result = exec.send(:send_conversation, conversation)
      expect(result).to eq('assistant message')
      expect(exec.last_usage_data).to eq({ input_tokens: 10, output_tokens: 5 })
    end

    it 'handles API error in response' do
      exec = described_class.new(**params)
      allow(exec).to receive(:init_new_request)
      allow(exec).to receive(:client_request).and_return({ 'error' => 'api error' })

      result = exec.send(:send_conversation, conversation)
      expect(result).to be_nil
      expect(exec.last_error).to eq({ 'error' => 'api error' })
    end

    it 'handles StandardError and sets last_error' do
      exec = described_class.new(**params)
      allow(exec).to receive(:init_new_request)
      allow(exec).to receive(:client_request).and_raise(StandardError.new('api error'))

      result = exec.send(:send_conversation, conversation)
      expect(result).to be_nil
      expect(exec.last_error).to include('error' => 'api error')
    end
  end
end 