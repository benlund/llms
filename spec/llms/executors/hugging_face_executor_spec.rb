require 'spec_helper'

RSpec.describe LLMs::Executors::HuggingFaceExecutor do
  let(:params) do
    {
      model_name: 'meta-llama/Llama-2-7b-chat-hf',
      pricing: { input: 1.0, output: 2.0 },
      api_key: 'fake',
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
    it 'raises error if api_key is missing' do
      expect {
        described_class.new(**params.merge(api_key: nil))
      }.to raise_error(LLMs::ConfigurationError, /No API key provided/)
    end

    it 'initializes client with correct base URL' do
      exec = described_class.new(**params)
      expect(exec.client).to be_a(LLMs::APIs::OpenAICompatibleAPI)
      expect(exec.instance_variable_get(:@base_url)).to eq("https://api-inference.huggingface.co/models/meta-llama/Llama-2-7b-chat-hf/v1")
    end
  end

  describe '#calculate_usage' do
    let(:executor) { described_class.new(**params) }

    it 'calculates usage from basic response' do
      response = {
        'usage' => {
          'prompt_tokens' => 100,
          'completion_tokens' => 50
        }
      }
      
      usage = executor.send(:calculate_usage, response, 1.5)
      
      expect(usage[:input_tokens]).to eq(100)
      expect(usage[:output_tokens]).to eq(50)
      expect(usage[:cache_was_written]).to be_nil
      expect(usage[:cache_was_read]).to be false
      expect(usage[:token_details]).to eq({ input: 100, output: 50 })
      expect(usage[:execution_time]).to eq(1.5)
      expect(usage[:estimated_cost]).to be_within(0.01).of(0.0002) # (100/1M)*1 + (50/1M)*2
    end

    it 'handles response without usage data' do
      response = { 'choices' => [{ 'message' => { 'content' => 'Hello' } }] }
      
      usage = executor.send(:calculate_usage, response, 1.0)
      
      expect(usage[:input_tokens]).to be_nil
      expect(usage[:output_tokens]).to be_nil
      expect(usage[:cache_was_written]).to be_nil
      expect(usage[:cache_was_read]).to be_nil
      expect(usage[:token_details]).to eq({})
      expect(usage[:execution_time]).to eq(1.0)
      expect(usage[:estimated_cost]).to be_nil
    end

    it 'handles empty usage data' do
      response = { 'usage' => {} }
      
      usage = executor.send(:calculate_usage, response, 0.5)
      
      expect(usage[:input_tokens]).to eq(0)
      expect(usage[:output_tokens]).to eq(0)
      expect(usage[:cache_was_written]).to be_nil
      expect(usage[:cache_was_read]).to be false
      expect(usage[:token_details]).to eq({})
      expect(usage[:execution_time]).to eq(0.5)
      expect(usage[:estimated_cost]).to be_nil # Empty token_counts returns nil
    end
  end

  describe '#send_conversation' do
    it 'returns a message and sets usage data' do
      exec = described_class.new(**params)
      allow(exec).to receive(:init_new_request)
      allow(exec).to receive(:client_request).and_return(api_response)
      allow(LLMs::Adapters::OpenAICompatibleMessageAdapter).to receive(:find_message_id).and_return('msgid')
      allow(LLMs::Adapters::OpenAICompatibleMessageAdapter).to receive(:message_from_api_format).and_return('assistant message')
      allow(exec).to receive(:calculate_usage).and_return({ 
        input_tokens: 10, 
        output_tokens: 20,
        token_details: { input: 10, output: 20 },
        execution_time: 1.0,
        estimated_cost: 0.00004
      })

      result = exec.send(:send_conversation, conversation)
      expect(result).to eq('assistant message')
      expect(exec.last_usage_data).to include(
        input_tokens: 10,
        output_tokens: 20,
        token_details: { input: 10, output: 20 },
        execution_time: 1.0,
        estimated_cost: 0.00004
      )
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
