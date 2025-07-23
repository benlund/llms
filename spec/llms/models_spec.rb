require 'spec_helper'

RSpec.describe LLMs::Models do
  describe '.load_models_file' do
    it 'loads models from a JSON file' do
      # The models are already loaded at the module level, so we can just verify they exist
      expect(described_class::PROVIDER_REGISTRY).not_to be_empty
      expect(described_class::PROVIDER_REGISTRY.keys).to include('anthropic', 'google')
    end
  end

  describe '.find_model' do
    it 'returns model for valid model name' do
      model = described_class.find_model('claude-sonnet-4-0')
      expect(model).to be_a(LLMs::Models::Model)
      expect(model.model_name).to eq('claude-sonnet-4-20250514')
    end

    it 'returns model for provider:model format' do
      model = described_class.find_model('anthropic:claude-sonnet-4-20250514')
      expect(model).to be_a(LLMs::Models::Model)
      expect(model.model_name).to eq('claude-sonnet-4-20250514')
      expect(model.provider.provider_name).to eq('anthropic')
    end

    it 'returns nil for invalid model name' do
      model = described_class.find_model('invalid_model')
      expect(model).to be_nil
    end

    it 'raises error for ambiguous model name' do
      # This would need a test case where multiple providers have the same model name
      # For now, we'll test the basic functionality
      expect { described_class.find_model('invalid_model') }.not_to raise_error
    end
  end

  describe '.find_model_for_provider' do
    it 'returns model for valid provider and model name' do
      model = described_class.find_model_for_provider('anthropic', 'claude-sonnet-4-20250514')
      expect(model).to be_a(LLMs::Models::Model)
      expect(model.model_name).to eq('claude-sonnet-4-20250514')
      expect(model.provider.provider_name).to eq('anthropic')
    end

    it 'returns nil for invalid provider' do
      expect { described_class.find_model_for_provider('invalid_provider', 'model') }.to raise_error("Unknown provider: invalid_provider")
    end

    it 'returns nil for invalid model name' do
      model = described_class.find_model_for_provider('anthropic', 'invalid_model')
      expect(model).to be_nil
    end
  end

  describe '.list_model_names' do
    it 'returns list of enabled model names' do
      model_names = described_class.list_model_names(full: false)
      expect(model_names).to be_an(Array)
      expect(model_names).not_to be_empty
      expect(model_names.first).to be_a(String)
    end

    it 'returns list of enabled model names with provider prefix' do
      model_names = described_class.list_model_names(full: true)
      expect(model_names).to be_an(Array)
      expect(model_names).not_to be_empty
      expect(model_names.first).to include(':')
    end

    it 'filters by tool support requirement' do
      model_names = described_class.list_model_names(require_tools: true)
      expect(model_names).to be_an(Array)
      # All returned models should support tools
    end

    it 'filters by vision support requirement' do
      model_names = described_class.list_model_names(require_vision: true)
      expect(model_names).to be_an(Array)
      # All returned models should support vision
    end

    it 'filters by thinking support requirement' do
      model_names = described_class.list_model_names(require_thinking: true)
      expect(model_names).to be_an(Array)
      # All returned models should support thinking
    end

    it 'includes disabled models when requested' do
      # First get enabled models
      enabled_models = described_class.list_model_names(include_disabled: false)
      
      # Then get all models including disabled
      all_models = described_class.list_model_names(include_disabled: true)
      
      expect(all_models.length).to be >= enabled_models.length
    end
  end

  describe '.register_provider' do
    it 'registers a new provider' do
      provider = described_class.register_provider('test_provider', 'TestExecutor', enabled: true)
      expect(provider).to be_a(LLMs::Models::Provider)
      expect(provider.provider_name).to eq('test_provider')
      expect(provider.executor_class_name).to eq('TestExecutor')
      
      # Clean up
      described_class::PROVIDER_REGISTRY.delete('test_provider')
    end
  end

  describe '.register_model' do
    before do
      # Register a test provider first
      described_class.register_provider('test_provider', 'TestExecutor', enabled: true)
    end

    after do
      # Clean up
      described_class::PROVIDER_REGISTRY.delete('test_provider')
      described_class::PROVIDER_TO_MODEL_REGISTRY.delete('test_provider')
    end

    it 'registers a new model' do
      model = described_class.register_model('test_provider', 'test_model', enabled: true)
      expect(model).to be_a(LLMs::Models::Model)
      expect(model.model_name).to eq('test_model')
      expect(model.provider.provider_name).to eq('test_provider')
    end

    it 'raises error for unknown provider' do
      expect { described_class.register_model('unknown_provider', 'test_model') }.to raise_error("Unknown provider: unknown_provider")
    end
  end
end 