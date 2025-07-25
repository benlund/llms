require 'spec_helper'

RSpec.describe LLMs::Models::Model do
  let(:provider) do
    LLMs::Models::Provider.new(
      'test_provider',
      'TestExecutor',
      supports_tools: true,
      supports_vision: true,
      supports_thinking: true,
      enabled: true
    )
  end

  let(:pricing) do
    {
      input: 0.03,
      output: 0.06,
      cache_read: 0.01,
      cache_write: 0.02
    }
  end

  let(:model) do
    described_class.new(
      'test-model',
      provider,
      pricing: pricing,
      supports_tools: true,
      supports_vision: true,
      supports_thinking: true,
      enabled: true
    )
  end

  describe '#initialize' do
    it 'sets the model name, provider, and attributes' do
      expect(model.model_name).to eq('test-model')
      expect(model.provider).to eq(provider)
      expect(model.pricing).to eq(pricing)
      expect(model.supports_tools).to be true
      expect(model.supports_vision).to be true
      expect(model.supports_thinking).to be true
      expect(model.enabled).to be true
    end

    it 'handles nil values for optional parameters' do
      model = described_class.new('test-model', provider)
      expect(model.pricing).to be_nil
      expect(model.supports_tools).to be_nil
      expect(model.supports_vision).to be_nil
      expect(model.supports_thinking).to be_nil
      expect(model.enabled).to be_nil
    end
  end

  describe '#full_name' do
    it 'returns provider:model format' do
      expect(model.full_name).to eq('test_provider:test-model')
    end
  end

  describe '#possibly_supports_tools?' do
    it 'returns true when provider supports tools and model does not explicitly disable' do
      expect(model.possibly_supports_tools?).to be true
    end

    it 'returns false when model explicitly disables tools' do
      model = described_class.new('test-model', provider, supports_tools: false)
      expect(model.possibly_supports_tools?).to be false
    end

    it 'returns false when provider does not support tools' do
      provider = LLMs::Models::Provider.new('test_provider', 'TestExecutor', supports_tools: false)
      model = described_class.new('test-model', provider)
      expect(model.possibly_supports_tools?).to be false
    end
  end

  describe '#certainly_supports_tools?' do
    it 'returns true when provider certainly supports tools and model does not disable' do
      provider = LLMs::Models::Provider.new('test_provider', 'TestExecutor', supports_tools: true)
      model = described_class.new('test-model', provider, supports_tools: true)
      expect(model.certainly_supports_tools?).to be true
    end

    it 'returns true when provider possibly supports tools and model explicitly enables' do
      provider = LLMs::Models::Provider.new('test_provider', 'TestExecutor', supports_tools: nil)
      model = described_class.new('test-model', provider, supports_tools: true)
      expect(model.certainly_supports_tools?).to be true
    end

    it 'returns false when model explicitly disables tools' do
      model = described_class.new('test-model', provider, supports_tools: false)
      expect(model.certainly_supports_tools?).to be false
    end
  end

  describe '#possibly_supports_vision?' do
    it 'returns true when provider supports vision and model does not explicitly disable' do
      expect(model.possibly_supports_vision?).to be true
    end

    it 'returns false when model explicitly disables vision' do
      model = described_class.new('test-model', provider, supports_vision: false)
      expect(model.possibly_supports_vision?).to be false
    end
  end

  describe '#certainly_supports_vision?' do
    it 'returns true when provider certainly supports vision and model does not disable' do
      provider = LLMs::Models::Provider.new('test_provider', 'TestExecutor', supports_vision: true)
      model = described_class.new('test-model', provider, supports_vision: true)
      expect(model.certainly_supports_vision?).to be true
    end

    it 'returns true when provider possibly supports vision and model explicitly enables' do
      provider = LLMs::Models::Provider.new('test_provider', 'TestExecutor', supports_vision: nil)
      model = described_class.new('test-model', provider, supports_vision: true)
      expect(model.certainly_supports_vision?).to be true
    end
  end

  describe '#possibly_supports_thinking?' do
    it 'returns true when provider supports thinking and model does not explicitly disable' do
      expect(model.possibly_supports_thinking?).to be true
    end

    it 'returns false when model explicitly disables thinking' do
      model = described_class.new('test-model', provider, supports_thinking: false)
      expect(model.possibly_supports_thinking?).to be false
    end
  end

  describe '#certainly_supports_thinking?' do
    it 'returns true when provider certainly supports thinking and model does not disable' do
      provider = LLMs::Models::Provider.new('test_provider', 'TestExecutor', supports_thinking: true)
      model = described_class.new('test-model', provider, supports_thinking: true)
      expect(model.certainly_supports_thinking?).to be true
    end

    it 'returns true when provider possibly supports thinking and model explicitly enables' do
      provider = LLMs::Models::Provider.new('test_provider', 'TestExecutor', supports_thinking: nil)
      model = described_class.new('test-model', provider, supports_thinking: true)
      expect(model.certainly_supports_thinking?).to be true
    end
  end

  describe '#is_enabled?' do
    it 'returns true when provider and model are enabled' do
      expect(model.is_enabled?).to be true
    end

    it 'returns false when provider is disabled' do
      provider = LLMs::Models::Provider.new('test_provider', 'TestExecutor', enabled: false)
      model = described_class.new('test-model', provider, enabled: true)
      expect(model.is_enabled?).to be false
    end

    it 'returns false when model is disabled' do
      model = described_class.new('test-model', provider, enabled: false)
      expect(model.is_enabled?).to be false
    end
  end

  describe '#calculate_cost' do
    it 'calculates cost based on input and output tokens' do
      cost = model.calculate_cost(1000, 500)
      expected_cost = (1000 / 1_000_000.0) * 0.03 + (500 / 1_000_000.0) * 0.06
      expect(cost).to eq(expected_cost)
    end

    it 'calculates cost including cache tokens' do
      cost = model.calculate_cost(1000, 500, 200, 100)
      expected_cost = (1000 / 1_000_000.0) * 0.03 + (500 / 1_000_000.0) * 0.06 +
                     (200 / 1_000_000.0) * 0.01 + (100 / 1_000_000.0) * 0.02
      expect(cost).to eq(expected_cost)
    end

    it 'returns 0.0 when pricing is empty' do
      model = described_class.new('test-model', provider, pricing: {})
      cost = model.calculate_cost(1000, 500)
      expect(cost).to eq(0.0)
    end

    it 'handles zero tokens' do
      cost = model.calculate_cost(0, 0)
      expect(cost).to eq(0.0)
    end

    it 'handles nil tokens' do
      cost = model.calculate_cost(nil, nil)
      expect(cost).to eq(0.0)
    end
  end
end
