require 'spec_helper'

RSpec.describe LLMs::Executors::BaseExecutor do
  let(:params) do
    {
      model_name: 'test-model',
      pricing: { input: 3.0, output: 15.0, cache_read: 0.3, cache_write: 3.75 },
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
      expect(exec.send(:calculate_cost, 100, 100)).to be_nil
    end

    it 'raises error if empty or incomplete pricing' do
      exec = DummyExecutor.new(**params.merge(pricing: {}))
      expect { exec.send(:calculate_cost, 100, 100) }.to raise_error(LLMs::CostCalculationError)
      exec = DummyExecutor.new(**params.merge(pricing: { input: 3.0 }))
      expect { exec.send(:calculate_cost, 100, 100) }.to raise_error(LLMs::CostCalculationError)
      exec = DummyExecutor.new(**params.merge(pricing: { output: 15.0 }))
      expect { exec.send(:calculate_cost, 100, 100) }.to raise_error(LLMs::CostCalculationError)
    end

    it 'calculates cost for input and output tokens' do
      cost = exec.send(:calculate_cost, 1_000_000, 500_000)
      expect(cost).to be_within(0.01).of(3.0 + 7.5)
    end

    it 'calculates cost for cache tokens' do
      cost = exec.send(:calculate_cost, 0, 0, 1_000_000, 1_000_000)
      expect(cost).to be_within(0.01).of(3.75 + 0.3)
    end

    it 'raises error if cache_write pricing missing' do
      limited_pricing = { input: 3.0, output: 15.0 }
      exec = DummyExecutor.new(**params.merge(pricing: limited_pricing))
      expect {
        exec.send(:calculate_cost, 0, 0, 1_000_000, 0)
      }.to raise_error(LLMs::CostCalculationError, /Cache write pricing/)
    end

    it 'raises error if cache_read pricing missing' do
      limited_pricing = { input: 3.0, output: 15.0 }
      exec = DummyExecutor.new(**params.merge(pricing: limited_pricing))
      expect {
        exec.send(:calculate_cost, 0, 0, 0, 1_000_000)
      }.to raise_error(LLMs::CostCalculationError, /Cache read pricing/)
    end
  end
end
