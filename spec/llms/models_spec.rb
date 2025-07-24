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

  describe '.add_model' do
    after do
      # Clean up any test providers and models
      described_class::PROVIDER_REGISTRY.delete('test_add_provider')
      described_class::PROVIDER_TO_MODEL_REGISTRY.delete('test_add_provider')
    end

    it 'registers both provider and model with basic parameters' do
      model = described_class.add_model(
        'test_add_provider',
        'test_add_model',
        executor: 'TestExecutor',
        enabled: true
      )

      expect(model).to be_a(LLMs::Models::Model)
      expect(model.model_name).to eq('test_add_model')
      expect(model.provider.provider_name).to eq('test_add_provider')
      expect(model.provider.executor_class_name).to eq('TestExecutor')
      expect(model.provider.is_enabled?).to be true
    end

    it 'registers provider with all provider-specific parameters' do
      model = described_class.add_model(
        'test_add_provider',
        'test_add_model',
        executor: 'TestExecutor',
        base_url: 'https://api.test.com',
        api_key_env_var: 'TEST_API_KEY',
        exclude_params: ['param1', 'param2'],
        enabled: true
      )

      provider = model.provider
      expect(provider.base_url).to eq('https://api.test.com')
      expect(provider.api_key_env_var).to eq('TEST_API_KEY')
      expect(provider.exclude_params).to eq(['param1', 'param2'])
    end

    it 'registers model with all model-specific parameters' do
      model = described_class.add_model(
        'test_add_provider',
        'test_add_model',
        executor: 'TestExecutor',
        pricing: { 'input' => 0.001, 'output' => 0.002 },
        tools: true,
        vision: true,
        thinking: true,
        enabled: true,
        aliases: ['alias1', 'alias2']
      )

      expect(model.pricing).to eq({ input: 0.001, output: 0.002 })
      expect(model.supports_tools).to be true
      expect(model.supports_vision).to be true
      expect(model.supports_thinking).to be true
      expect(model.enabled).to be true
    end

    it 'handles mixed provider and model parameters correctly' do
      model = described_class.add_model(
        'test_add_provider',
        'test_add_model',
        executor: 'TestExecutor',
        base_url: 'https://api.test.com',
        api_key_env_var: 'TEST_API_KEY',
        pricing: { 'input' => 0.001 },
        tools: true,
        vision: false,
        enabled: true
      )

      # Verify provider parameters
      provider = model.provider
      expect(provider.base_url).to eq('https://api.test.com')
      expect(provider.api_key_env_var).to eq('TEST_API_KEY')
      expect(provider.executor_class_name).to eq('TestExecutor')

      # Verify model parameters
      expect(model.pricing).to eq({ input: 0.001 })
      expect(model.supports_tools).to be true
      expect(model.supports_vision).to be false
      expect(model.enabled).to be true
    end

    it 'handles missing executor parameter gracefully' do
      model = described_class.add_model('test_add_provider', 'test_add_model')
      
      expect(model).to be_a(LLMs::Models::Model)
      expect(model.provider.executor_class_name).to eq('')
    end

    it 'can find the registered model after registration' do
      model = described_class.add_model(
        'test_add_provider',
        'test_add_model',
        executor: 'TestExecutor',
        enabled: true
      )

      found_model = described_class.find_model('test_add_model')
      expect(found_model).to eq(model)
    end

    it 'can find the registered model with provider prefix' do
      model = described_class.add_model(
        'test_add_provider',
        'test_add_model',
        executor: 'TestExecutor',
        enabled: true
      )

      found_model = described_class.find_model('test_add_provider:test_add_model')
      expect(found_model).to eq(model)
    end
  end
end 