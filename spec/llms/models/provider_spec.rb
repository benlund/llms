require 'spec_helper'

RSpec.describe LLMs::Models::Provider do
  let(:provider) do
    described_class.new(
      'test_provider',
      'TestExecutor',
      base_url: 'https://api.test.com/v1',
      api_key_env_var: 'TEST_API_KEY',
      supports_tools: true,
      supports_vision: true,
      supports_thinking: true,
      enabled: true,
      exclude_params: ['param1', 'param2']
    )
  end

  describe '#initialize' do
    it 'sets all the provider attributes' do
      expect(provider.provider_name).to eq('test_provider')
      expect(provider.executor_class_name).to eq('TestExecutor')
      expect(provider.base_url).to eq('https://api.test.com/v1')
      expect(provider.api_key_env_var).to eq('TEST_API_KEY')
      expect(provider.supports_tools).to be true
      expect(provider.supports_vision).to be true
      expect(provider.supports_thinking).to be true
      expect(provider.enabled).to be true
      expect(provider.exclude_params).to eq(['param1', 'param2'])
    end

    it 'handles nil values for optional parameters' do
      provider = described_class.new('test_provider', 'TestExecutor')
      expect(provider.base_url).to be_nil
      expect(provider.api_key_env_var).to be_nil
      expect(provider.supports_tools).to be_nil
      expect(provider.supports_vision).to be_nil
      expect(provider.supports_thinking).to be_nil
      expect(provider.enabled).to be_nil
      expect(provider.exclude_params).to be_nil
    end

    it 'converts provider_name and executor_class_name to strings' do
      provider = described_class.new(:test_provider, :TestExecutor)
      expect(provider.provider_name).to eq('test_provider')
      expect(provider.executor_class_name).to eq('TestExecutor')
    end
  end

  describe '#possibly_supports_tools?' do
    it 'returns true when tools are explicitly supported' do
      provider = described_class.new('test_provider', 'TestExecutor', supports_tools: true)
      expect(provider.possibly_supports_tools?).to be true
    end

    it 'returns true when tools support is unspecified (nil)' do
      provider = described_class.new('test_provider', 'TestExecutor', supports_tools: nil)
      expect(provider.possibly_supports_tools?).to be true
    end

    it 'returns false when tools are explicitly disabled' do
      provider = described_class.new('test_provider', 'TestExecutor', supports_tools: false)
      expect(provider.possibly_supports_tools?).to be false
    end
  end

  describe '#certainly_supports_tools?' do
    it 'returns true when tools are explicitly supported' do
      provider = described_class.new('test_provider', 'TestExecutor', supports_tools: true)
      expect(provider.certainly_supports_tools?).to be true
    end

    it 'returns false when tools support is unspecified (nil)' do
      provider = described_class.new('test_provider', 'TestExecutor', supports_tools: nil)
      expect(provider.certainly_supports_tools?).to be false
    end

    it 'returns false when tools are explicitly disabled' do
      provider = described_class.new('test_provider', 'TestExecutor', supports_tools: false)
      expect(provider.certainly_supports_tools?).to be false
    end
  end

  describe '#possibly_supports_vision?' do
    it 'returns true when vision is explicitly supported' do
      provider = described_class.new('test_provider', 'TestExecutor', supports_vision: true)
      expect(provider.possibly_supports_vision?).to be true
    end

    it 'returns true when vision support is unspecified (nil)' do
      provider = described_class.new('test_provider', 'TestExecutor', supports_vision: nil)
      expect(provider.possibly_supports_vision?).to be true
    end

    it 'returns false when vision is explicitly disabled' do
      provider = described_class.new('test_provider', 'TestExecutor', supports_vision: false)
      expect(provider.possibly_supports_vision?).to be false
    end
  end

  describe '#certainly_supports_vision?' do
    it 'returns true when vision is explicitly supported' do
      provider = described_class.new('test_provider', 'TestExecutor', supports_vision: true)
      expect(provider.certainly_supports_vision?).to be true
    end

    it 'returns false when vision support is unspecified (nil)' do
      provider = described_class.new('test_provider', 'TestExecutor', supports_vision: nil)
      expect(provider.certainly_supports_vision?).to be false
    end

    it 'returns false when vision is explicitly disabled' do
      provider = described_class.new('test_provider', 'TestExecutor', supports_vision: false)
      expect(provider.certainly_supports_vision?).to be false
    end
  end

  describe '#possibly_supports_thinking?' do
    it 'returns true when thinking is explicitly supported' do
      provider = described_class.new('test_provider', 'TestExecutor', supports_thinking: true)
      expect(provider.possibly_supports_thinking?).to be true
    end

    it 'returns true when thinking support is unspecified (nil)' do
      provider = described_class.new('test_provider', 'TestExecutor', supports_thinking: nil)
      expect(provider.possibly_supports_thinking?).to be true
    end

    it 'returns false when thinking is explicitly disabled' do
      provider = described_class.new('test_provider', 'TestExecutor', supports_thinking: false)
      expect(provider.possibly_supports_thinking?).to be false
    end
  end

  describe '#certainly_supports_thinking?' do
    it 'returns true when thinking is explicitly supported' do
      provider = described_class.new('test_provider', 'TestExecutor', supports_thinking: true)
      expect(provider.certainly_supports_thinking?).to be true
    end

    it 'returns false when thinking support is unspecified (nil)' do
      provider = described_class.new('test_provider', 'TestExecutor', supports_thinking: nil)
      expect(provider.certainly_supports_thinking?).to be false
    end

    it 'returns false when thinking is explicitly disabled' do
      provider = described_class.new('test_provider', 'TestExecutor', supports_thinking: false)
      expect(provider.certainly_supports_thinking?).to be false
    end
  end

  describe '#is_enabled?' do
    it 'returns true when provider is explicitly enabled' do
      provider = described_class.new('test_provider', 'TestExecutor', enabled: true)
      expect(provider.is_enabled?).to be true
    end

    it 'returns true when enabled status is unspecified (nil)' do
      provider = described_class.new('test_provider', 'TestExecutor', enabled: nil)
      expect(provider.is_enabled?).to be true
    end

    it 'returns false when provider is explicitly disabled' do
      provider = described_class.new('test_provider', 'TestExecutor', enabled: false)
      expect(provider.is_enabled?).to be false
    end
  end
end 