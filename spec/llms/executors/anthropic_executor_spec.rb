require 'spec_helper'

RSpec.describe LLMs::Executors::AnthropicExecutor do
  let(:params) do
    {
      model_name: 'claude-3-5-sonnet-20241022',
      pricing: { input: 3.0, output: 15.0, cache_read: 0.3, cache_write_1hr: 3.75, cache_write_5min: 3.0 },
      temperature: 0.0,
      max_tokens: 1000,
      api_key_env_var: 'ANTHROPIC_API_KEY'
    }
  end

  let(:conversation) { instance_double('LLMs::Conversation', last_message: 'user message', system_message: 'system', available_tools: [], messages: []) }
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

  describe '#calculate_usage' do
    let(:executor) { described_class.new(**params) }

    it 'calculates usage from basic response' do
      response = {
        'usage' => {
          'input_tokens' => 100,
          'output_tokens' => 50
        }
      }
      
      usage = executor.send(:calculate_usage, response, 1.5)
      
      expect(usage[:input_tokens]).to eq(100)
      expect(usage[:output_tokens]).to eq(50)
      expect(usage[:cache_was_written]).to be false
      expect(usage[:cache_was_read]).to be false
      expect(usage[:token_details]).to eq({ input: 100, output: 50 })
      expect(usage[:execution_time]).to eq(1.5)
      expect(usage[:estimated_cost]).to be_within(0.01).of(0.0006) # (100/1M)*3 + (50/1M)*15
    end

    it 'calculates usage with cache creation tokens' do
      response = {
        'usage' => {
          'input_tokens' => 100,
          'output_tokens' => 50,
          'cache_creation_input_tokens' => 25
        }
      }
      
      usage = executor.send(:calculate_usage, response, 1.0)
      
      expect(usage[:input_tokens]).to eq(125) # 100 + 25
      expect(usage[:output_tokens]).to eq(50)
      expect(usage[:cache_was_written]).to be true
      expect(usage[:cache_was_read]).to be false
      expect(usage[:token_details]).to eq({ 
        input: 100, 
        output: 50, 
        cache_write_5min: 25 
      })
    end

    it 'calculates usage with cache read tokens' do
      response = {
        'usage' => {
          'input_tokens' => 100,
          'output_tokens' => 50,
          'cache_read_input_tokens' => 30
        }
      }
      
      usage = executor.send(:calculate_usage, response, 0.8)
      
      expect(usage[:input_tokens]).to eq(130) # 100 + 30
      expect(usage[:output_tokens]).to eq(50)
      expect(usage[:cache_was_written]).to be false
      expect(usage[:cache_was_read]).to be true
      expect(usage[:token_details]).to eq({ 
        input: 100, 
        output: 50, 
        cache_read: 30 
      })
    end

    it 'calculates usage with detailed cache creation' do
      response = {
        'usage' => {
          'input_tokens' => 100,
          'output_tokens' => 50,
          'cache_creation' => {
            'ephemeral_1h_input_tokens' => 20,
            'ephemeral_5min_input_tokens' => 10
          }
        }
      }
      
      usage = executor.send(:calculate_usage, response, 2.0)
      
      expect(usage[:input_tokens]).to eq(100) # Only input_tokens, cache tokens are separate
      expect(usage[:output_tokens]).to eq(50)
      expect(usage[:cache_was_written]).to be true
      expect(usage[:cache_was_read]).to be false
      expect(usage[:token_details]).to eq({ 
        input: 100, 
        output: 50, 
        cache_write_1hr: 20,
        cache_write_5min: 10
      })
    end

    it 'handles response without usage data' do
      response = { 'some_other_data' => 'value' }
      
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
      expect(usage[:cache_was_written]).to be false
      expect(usage[:cache_was_read]).to be false
      expect(usage[:token_details]).to eq({})
      expect(usage[:execution_time]).to eq(0.5)
      expect(usage[:estimated_cost]).to be_nil # Empty token_counts returns nil
    end
  end

  describe '#send_conversation' do
    it 'returns a message and sets usage data' do
      executor = described_class.new(**params)
      allow(executor).to receive(:init_new_request)
      allow(executor).to receive(:client_request).and_return(api_response)
      allow(LLMs::Adapters::AnthropicMessageAdapter).to receive(:find_message_id).and_return('msgid')
      allow(LLMs::Adapters::AnthropicMessageAdapter).to receive(:message_from_api_format).and_return('assistant message')
      allow(executor).to receive(:calculate_usage).and_return({ 
        input_tokens: 10, 
        output_tokens: 20,
        token_details: { input: 10, output: 20 },
        execution_time: 1.0,
        estimated_cost: 0.0003
      })

      result = executor.send(:send_conversation, conversation)
      expect(result).to eq('assistant message')
      expect(executor.last_usage_data).to include(
        input_tokens: 10,
        output_tokens: 20,
        token_details: { input: 10, output: 20 },
        execution_time: 1.0,
        estimated_cost: 0.0003
      )
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
