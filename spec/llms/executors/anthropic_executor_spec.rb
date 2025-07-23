require 'spec_helper'

RSpec.describe LLMs::Executors::AnthropicExecutor do
  let(:params) do
    {
      model_name: 'claude-3-5-sonnet-20241022',
      pricing: { input: 3.0, output: 15.0 },
      temperature: 0.0,
      max_tokens: 1000,
      api_key_env_var: 'ANTHROPIC_API_KEY'
    }
  end

  let(:conversation) { instance_double('LLMs::Conversation', last_message: 'user message', system_message: 'system', available_tools: [], formatted_messages: []) }
  let(:api_response) { { 'usage' => { 'input_tokens' => 10, 'output_tokens' => 20 } } }

  before do
    stub_const('Anthropic::Client', Class.new do
      def initialize(access_token:); end
      def messages(parameters:); { 'usage' => { 'input_tokens' => 10, 'output_tokens' => 20 } } end
    end)
    allow(ENV).to receive(:[]).with('ANTHROPIC_API_KEY').and_return('fake-key')
  end

  describe '#initialize_client' do
    it 'raises error if API key is not set' do
      allow(ENV).to receive(:[]).with('ANTHROPIC_API_KEY').and_return(nil)
      expect {
        described_class.new(**params)
      }.to raise_error(RuntimeError, /ANTHROPIC_API_KEY not set/)
    end

    it 'initializes client if API key is set' do
      exec = described_class.new(**params)
      expect(exec.client).to be_a(Anthropic::Client)
    end
  end

  describe '#send_conversation' do
    it 'returns a message and sets usage data' do
      executor = described_class.new(**params)
      allow(executor).to receive(:init_new_request)
      allow(executor).to receive(:client_request).and_return(api_response)
      allow(LLMs::Adapters::AnthropicMessageAdapter).to receive(:find_message_id).and_return('msgid')
      allow(LLMs::Adapters::AnthropicMessageAdapter).to receive(:message_from_api_format).and_return('assistant message')
      allow(executor).to receive(:calculate_usage).and_return({ input_tokens: 10, output_tokens: 20 })

      result = executor.send(:send_conversation, conversation)
      expect(result).to eq('assistant message')
      expect(executor.last_usage_data).to eq({ input_tokens: 10, output_tokens: 20 })
      expect(executor.last_received_message_id).to eq('msgid')
      expect(executor.last_received_message).to eq('assistant message')
    end

    it 'handles Faraday::BadRequestError and sets last_error' do
      executor = described_class.new(**params)
      allow(executor).to receive(:init_new_request)
      
      # Create a proper exception class for testing
      error_class = Class.new(StandardError) do
        attr_reader :response
        def initialize(response)
          @response = response
          super("Bad Request")
        end
      end
      stub_const('Faraday::BadRequestError', error_class)
      
      error = error_class.new({ body: 'bad request' })
      allow(executor).to receive(:client_request).and_raise(error)

      result = executor.send(:send_conversation, conversation)
      expect(result).to be_nil
      expect(executor.last_error).to eq('bad request')
    end

    it 'handles API error in response' do
      exec = described_class.new(**params)
      allow(exec).to receive(:init_new_request)
      allow(exec).to receive(:client_request).and_return({ 'error' => 'api error' })

      result = exec.send(:send_conversation, conversation)
      expect(result).to be_nil
      expect(exec.last_error).to eq('api error')
    end
  end
end
