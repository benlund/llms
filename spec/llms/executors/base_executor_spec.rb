require 'spec_helper'

RSpec.describe LLMs::Executors::BaseExecutor do
  let(:params) do
    {
      model_name: 'test-model',
      pricing: { input: 3.0, output: 15.0, cache_read: 0.3, cache_write_1hr: 3.75, cache_write_5min: 3.0 },
      temperature: 0.5,
      max_tokens: 1000
    }
  end

  class DummyExecutor < LLMs::Executors::BaseExecutor
    def initialize_client; end
    def execute_conversation(*); end
    def tool_schemas; []; end
    def calculate_usage(*); end
  end

  describe '#initialize' do
    it 'raises error if model_name is missing' do
      expect { DummyExecutor.new }.to raise_error(LLMs::ConfigurationError)
    end

    it 'sets parameters and validates them' do
      exec = DummyExecutor.new(**params)
      expect(exec.model_name).to eq('test-model')
      expect(exec.temperature).to eq(0.5)
      expect(exec.max_tokens).to eq(1000)
    end

    it 'raises error for invalid temperature' do
      expect {
        DummyExecutor.new(**params.merge(temperature: 3.0))
      }.to raise_error(LLMs::ConfigurationError, /Temperature/)
    end

    it 'raises error for invalid max_tokens' do
      expect {
        DummyExecutor.new(**params.merge(max_tokens: 0))
      }.to raise_error(LLMs::ConfigurationError, /max_tokens/)
    end
  end

  describe '#calculate_cost' do
    let(:exec) { DummyExecutor.new(**params) }

    it 'returns nil if no pricing' do
      exec = DummyExecutor.new(**params.merge(pricing: nil))
      expect(exec.send(:calculate_cost, { input: 100, output: 100 })).to be_nil
    end

    it 'returns nil if token_counts is nil or empty' do
      expect(exec.send(:calculate_cost, nil)).to be_nil
      expect(exec.send(:calculate_cost, {})).to be_nil
    end

    it 'raises error if pricing is missing required keys' do
      exec = DummyExecutor.new(**params.merge(pricing: {}))
      expect { exec.send(:calculate_cost, { input: 100, output: 100 }) }.to raise_error(LLMs::CostCalculationError, /Pricing missing key/)
      
      exec = DummyExecutor.new(**params.merge(pricing: { input: 3.0 }))
      expect { exec.send(:calculate_cost, { input: 100, output: 100 }) }.to raise_error(LLMs::CostCalculationError, /Pricing missing key/)
    end

    it 'calculates cost for input and output tokens' do
      token_counts = { input: 1_000_000, output: 500_000 }
      cost = exec.send(:calculate_cost, token_counts)
      expect(cost).to be_within(0.01).of(3.0 + 7.5)
    end

    it 'calculates cost for cache tokens' do
      token_counts = { cache_read: 1_000_000, cache_write_1hr: 1_000_000 }
      cost = exec.send(:calculate_cost, token_counts)
      expect(cost).to be_within(0.01).of(3.75 + 0.3)
    end

    it 'calculates cost for 5min cache write tokens' do
      token_counts = { cache_write_5min: 1_000_000 }
      cost = exec.send(:calculate_cost, token_counts)
      expect(cost).to be_within(0.01).of(3.0)
    end

    it 'ignores zero token counts' do
      token_counts = { input: 1_000_000, output: 0, cache_read: 0 }
      cost = exec.send(:calculate_cost, token_counts)
      expect(cost).to be_within(0.01).of(3.0)
    end

    it 'handles string keys in token_counts' do
      token_counts = { input: 1_000_000, output: 500_000 }
      cost = exec.send(:calculate_cost, token_counts)
      expect(cost).to be_within(0.01).of(3.0 + 7.5)
    end

    it 'handles string keys in pricing' do
      pricing = { input: 3.0, output: 15.0 }
      exec = DummyExecutor.new(**params.merge(pricing: pricing))
      token_counts = { input: 1_000_000, output: 500_000 }
      cost = exec.send(:calculate_cost, token_counts)
      expect(cost).to be_within(0.01).of(3.0 + 7.5)
    end
  end
end
