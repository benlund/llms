require 'spec_helper'

RSpec.describe LLMs::Usage::CostCalculator do
  let(:pricing) do
    {
      input: 3.00,      # $3.00 per million tokens
      output: 15.00,    # $15.00 per million tokens
      cache_read: 0.30, # $0.30 per million tokens
      cache_write: 3.75 # $3.75 per million tokens
    }
  end

  let(:calculator) { described_class.new(pricing) }

  describe '#initialize' do
    it 'creates calculator with pricing' do
      expect(calculator.instance_variable_get(:@pricing)).to eq(pricing)
    end

    it 'handles nil pricing' do
      calculator = described_class.new(nil)
      expect(calculator.instance_variable_get(:@pricing)).to eq({})
    end
  end

  describe '#calculate' do
    let(:usage_data) do
      LLMs::Usage::UsageData.new(
        input_tokens: 1_000_000,      # 1M tokens
        output_tokens: 500_000,       # 500K tokens
        cache_read_tokens: 100_000,   # 100K tokens
        cache_write_tokens: 50_000    # 50K tokens
      )
    end

    it 'calculates total cost correctly' do
      result = calculator.calculate(usage_data)
      
      expected_components = [
        { type: :input, tokens: 1_000_000, rate: 3.00, cost: 3.00 },
        { type: :output, tokens: 500_000, rate: 15.00, cost: 7.50 },
        { type: :cache_read, tokens: 100_000, rate: 0.30, cost: 0.03 },
        { type: :cache_write, tokens: 50_000, rate: 3.75, cost: 0.1875 }
      ]
      
      expect(result[:total_cost]).to be_within(0.001).of(10.7175)
      expect(result[:components]).to match_array(expected_components)
      expect(result[:currency]).to eq('USD')
    end

    it 'handles zero tokens' do
      usage_data = LLMs::Usage::UsageData.new
      result = calculator.calculate(usage_data)
      
      expect(result[:total_cost]).to eq(0.0)
      expect(result[:components]).to be_empty
    end

    it 'excludes components with zero tokens' do
      usage_data = LLMs::Usage::UsageData.new(
        input_tokens: 1_000_000,
        output_tokens: 0,
        cache_read_tokens: 0,
        cache_write_tokens: 0
      )
      
      result = calculator.calculate(usage_data)
      
      expect(result[:components].length).to eq(1)
      expect(result[:components].first[:type]).to eq(:input)
      expect(result[:total_cost]).to eq(3.00)
    end

    it 'handles missing pricing keys' do
      usage_data = LLMs::Usage::UsageData.new(
        input_tokens: 1_000_000,
        output_tokens: 500_000
      )
      
      limited_pricing = { input: 3.00 } # Missing output pricing
      calculator = described_class.new(limited_pricing)
      result = calculator.calculate(usage_data)
      
      expect(result[:components].length).to eq(1)
      expect(result[:components].first[:type]).to eq(:input)
      expect(result[:total_cost]).to eq(3.00)
    end
  end

  describe '#calculate_simple' do
    it 'calculates cost from individual token counts' do
      result = calculator.calculate_simple(
        input_tokens: 1_000_000,
        output_tokens: 500_000,
        cache_read_tokens: 100_000,
        cache_write_tokens: 50_000
      )
      
      expect(result[:total_cost]).to be_within(0.001).of(10.7175)
      expect(result[:components].length).to eq(4)
    end

    it 'uses default values for optional parameters' do
      result = calculator.calculate_simple(
        input_tokens: 1_000_000,
        output_tokens: 500_000
      )
      
      expect(result[:total_cost]).to eq(10.50)
      expect(result[:components].length).to eq(2)
    end
  end

  describe 'edge cases' do
    it 'handles very small token counts' do
      usage_data = LLMs::Usage::UsageData.new(
        input_tokens: 1,
        output_tokens: 1
      )
      
      result = calculator.calculate(usage_data)
      
      expect(result[:total_cost]).to be_within(0.000001).of(0.000018) # Very small cost
      expect(result[:components].length).to eq(2)
    end

    it 'handles empty pricing' do
      calculator = described_class.new({})
      usage_data = LLMs::Usage::UsageData.new(
        input_tokens: 1_000_000,
        output_tokens: 500_000
      )
      
      result = calculator.calculate(usage_data)
      
      expect(result[:total_cost]).to eq(0.0)
      expect(result[:components]).to be_empty
    end
  end
end 