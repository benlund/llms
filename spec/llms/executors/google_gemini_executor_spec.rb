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

  describe '#calculate_usage' do
    let(:executor) { described_class.new(**params) }

    it 'calculates usage from basic response' do
      response = {
        'usageMetadata' => {
          'promptTokenCount' => 100,
          'candidatesTokenCount' => 50
        }
      }
      
      usage = executor.send(:calculate_usage, response, 1.5)
      
      expect(usage[:input_tokens]).to eq(100)
      expect(usage[:output_tokens]).to eq(50)
      expect(usage[:cache_was_written]).to be false
      expect(usage[:cache_was_read]).to be false
      expect(usage[:token_details]).to eq({ input: 100, output: 50 })
      expect(usage[:execution_time]).to eq(1.5)
      expect(usage[:estimated_cost]).to be_within(0.01).of(0.000875) # (100/1M)*3.5 + (50/1M)*10.5
    end

    it 'calculates usage with thoughts tokens' do
      response = {
        'usageMetadata' => {
          'promptTokenCount' => 100,
          'thoughtsTokenCount' => 25,
          'candidatesTokenCount' => 50
        }
      }
      
      usage = executor.send(:calculate_usage, response, 1.0)
      
      expect(usage[:input_tokens]).to eq(100)
      expect(usage[:output_tokens]).to eq(75) # 25 + 50
      expect(usage[:cache_was_written]).to be false
      expect(usage[:cache_was_read]).to be false
      expect(usage[:token_details]).to eq({ 
        input: 100, 
        output: 75 
      })
    end

    it 'handles response without usage metadata' do
      response = { 'candidates' => [{ 'content' => { 'parts' => [{ 'text' => 'Hello' }] } }] }
      
      usage = executor.send(:calculate_usage, response, 1.0)
      
      expect(usage[:input_tokens]).to be_nil
      expect(usage[:output_tokens]).to be_nil
      expect(usage[:cache_was_written]).to be_nil
      expect(usage[:cache_was_read]).to be_nil
      expect(usage[:token_details]).to eq({})
      expect(usage[:execution_time]).to eq(1.0)
      expect(usage[:estimated_cost]).to be_nil
    end

    it 'handles empty usage metadata' do
      response = { 'usageMetadata' => {} }
      
      usage = executor.send(:calculate_usage, response, 0.5)
      
      expect(usage[:input_tokens]).to eq(0)
      expect(usage[:output_tokens]).to eq(0)
      expect(usage[:cache_was_written]).to be false
      expect(usage[:cache_was_read]).to be false
      expect(usage[:token_details]).to eq({})
      expect(usage[:execution_time]).to eq(0.5)
      expect(usage[:estimated_cost]).to be_nil # Empty token_counts returns nil
    end

    it 'handles missing token count fields' do
      response = {
        'usageMetadata' => {
          'promptTokenCount' => 100
          # missing candidatesTokenCount
        }
      }
      
      usage = executor.send(:calculate_usage, response, 1.0)
      
      expect(usage[:input_tokens]).to eq(100)
      expect(usage[:output_tokens]).to eq(0)
      expect(usage[:token_details]).to eq({ input: 100 })
    end
  end

  describe '#send_conversation' do
    it 'returns a message and sets usage data' do
      exec = described_class.new(**params)
      allow(exec).to receive(:init_new_request)
      allow(exec).to receive(:client_request).and_return(api_response)
      allow(LLMs::Adapters::GoogleGeminiMessageAdapter).to receive(:message_from_api_format).and_return('assistant message')
      allow(exec).to receive(:calculate_usage).and_return({ 
        input_tokens: 10, 
        output_tokens: 5,
        token_details: { input: 10, output: 5 },
        execution_time: 1.0,
        estimated_cost: 0.00014
      })

      result = exec.send(:send_conversation, conversation)
      expect(result).to eq('assistant message')
      expect(exec.last_usage_data).to include(
        input_tokens: 10,
        output_tokens: 5,
        token_details: { input: 10, output: 5 },
        execution_time: 1.0,
        estimated_cost: 0.00014
      )
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

    it 'handles nil message from adapter' do
      exec = described_class.new(**params)
      allow(exec).to receive(:init_new_request)
      allow(exec).to receive(:client_request).and_return(api_response)
      allow(LLMs::Adapters::GoogleGeminiMessageAdapter).to receive(:message_from_api_format).and_return(nil)

      result = exec.send(:send_conversation, conversation)
      expect(result).to be_nil
      expect(exec.last_error).to include('error' => 'No message found in the response. Can happen with thinking models if max_tokens is too low.')
    end
  end
end 