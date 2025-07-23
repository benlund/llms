require 'spec_helper'

RSpec.describe LLMs::Usage::UsageData do
  describe '#initialize' do
    it 'creates usage data with default values' do
      usage = described_class.new
      expect(usage.input_tokens).to eq(0)
      expect(usage.output_tokens).to eq(0)
      expect(usage.cache_read_tokens).to eq(0)
      expect(usage.cache_write_tokens).to eq(0)
      expect(usage.execution_time).to eq(0.0)
      expect(usage.model_name).to be_nil
    end

    it 'creates usage data with provided values' do
      usage = described_class.new(
        input_tokens: 100,
        output_tokens: 50,
        cache_read_tokens: 10,
        cache_write_tokens: 5,
        execution_time: 1.5,
        model_name: 'test-model'
      )
      
      expect(usage.input_tokens).to eq(100)
      expect(usage.output_tokens).to eq(50)
      expect(usage.cache_read_tokens).to eq(10)
      expect(usage.cache_write_tokens).to eq(5)
      expect(usage.execution_time).to eq(1.5)
      expect(usage.model_name).to eq('test-model')
    end

    it 'converts string values to appropriate types' do
      usage = described_class.new(
        input_tokens: '100',
        output_tokens: '50',
        execution_time: '1.5'
      )
      
      expect(usage.input_tokens).to eq(100)
      expect(usage.output_tokens).to eq(50)
      expect(usage.execution_time).to eq(1.5)
    end
  end

  describe '#total_tokens' do
    it 'calculates total tokens correctly' do
      usage = described_class.new(
        input_tokens: 100,
        output_tokens: 50,
        cache_read_tokens: 10,
        cache_write_tokens: 5
      )
      
      expect(usage.total_tokens).to eq(165)
    end

    it 'returns 0 for empty usage' do
      usage = described_class.new
      expect(usage.total_tokens).to eq(0)
    end
  end

  describe '#to_h' do
    it 'returns hash representation' do
      usage = described_class.new(
        input_tokens: 100,
        output_tokens: 50,
        cache_read_tokens: 10,
        cache_write_tokens: 5,
        execution_time: 1.5,
        model_name: 'test-model'
      )
      
      hash = usage.to_h
      expect(hash).to eq({
        input_tokens: 100,
        output_tokens: 50,
        cache_read_tokens: 10,
        cache_write_tokens: 5,
        total_tokens: 165,
        execution_time: 1.5,
        model_name: 'test-model'
      })
    end
  end

  describe '#to_s' do
    it 'formats usage string correctly' do
      usage = described_class.new(
        input_tokens: 100,
        output_tokens: 50,
        execution_time: 1.5
      )
      
      expect(usage.to_s).to eq('Usage: 150 tokens (100 input, 50 output) in 1.5s')
    end

    it 'includes cache tokens when present' do
      usage = described_class.new(
        input_tokens: 100,
        output_tokens: 50,
        cache_read_tokens: 10,
        cache_write_tokens: 5,
        execution_time: 1.5
      )
      
      expect(usage.to_s).to eq('Usage: 165 tokens (100 input, 50 output, 10 cache_read, 5 cache_write) in 1.5s')
    end

    it 'handles zero tokens' do
      usage = described_class.new(execution_time: 0.5)
      expect(usage.to_s).to eq('Usage: 0 tokens () in 0.5s')
    end
  end
end 