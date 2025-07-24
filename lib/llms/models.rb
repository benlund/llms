require 'json'
require_relative 'models/provider'
require_relative 'models/model'

module LLMs
  module Models

    DEFAULT_MODEL = 'claude-sonnet-4-0'

    PROVIDER_REGISTRY = {}
    PROVIDER_TO_MODEL_REGISTRY = {}
    MODEL_TO_PROVIDER_REGISTRY = {}
    ALIAS_REGISTRY = {}

    def self.register_model(provider_name, model_name, pricing: nil, tools: nil, vision: nil, thinking: nil, enabled: nil, aliases: nil)
      provider = PROVIDER_REGISTRY[provider_name.to_s]
      raise "Unknown provider: #{provider_name}" unless provider

      model = LLMs::Models::Model.new(
        model_name,
        provider,
        pricing:,
        supports_tools: tools,
        supports_vision: vision,
        supports_thinking: thinking,
        enabled: enabled
      )

      PROVIDER_TO_MODEL_REGISTRY[provider.provider_name] ||= {}
      PROVIDER_TO_MODEL_REGISTRY[provider.provider_name][model.model_name] = model

      MODEL_TO_PROVIDER_REGISTRY[model.model_name] ||= Set.new
      MODEL_TO_PROVIDER_REGISTRY[model.model_name] << provider.provider_name

      if aliases
        aliases.each do |alias_name|
          if aliased_model_name = ALIAS_REGISTRY[alias_name]
            raise "Alias #{alias_name} already registered for #{aliased_model_name}"
          end
          ALIAS_REGISTRY[alias_name] = model.model_name
        end
      end

      model
    end

    def self.register_provider(provider_name, executor_class_name, base_url: nil, api_key_env_var: nil, tools: nil, vision: nil, thinking: nil, enabled: nil, exclude_params: nil)
      provider = LLMs::Models::Provider.new(
        provider_name,
        executor_class_name,
        base_url:,
        api_key_env_var:,
        supports_tools: tools,
        supports_vision: vision,
        supports_thinking: thinking,
        enabled:,
        exclude_params:
      )

      PROVIDER_REGISTRY[provider.provider_name] = provider
    end

    def self.disable_model(provider_name, model_name)
      provider = PROVIDER_REGISTRY[provider_name.to_s]
      raise "Unknown provider: #{provider_name}" unless provider

      model = PROVIDER_TO_MODEL_REGISTRY[provider.provider_name][model_name]
      raise "Unknown model: #{model_name}" unless model

      model.enabled = false
    end

    def self.enable_model(provider_name, model_name)
      provider = PROVIDER_REGISTRY[provider_name.to_s]
      raise "Unknown provider: #{provider_name}" unless provider

      model = PROVIDER_TO_MODEL_REGISTRY[provider.provider_name][model_name]
      raise "Unknown model: #{model_name}" unless model

      model.enabled = true
    end

    def self.disable_provider(provider_name)
      provider = PROVIDER_REGISTRY[provider_name.to_s]
      raise "Unknown provider: #{provider_name}" unless provider

      provider.enabled = false
    end

    def self.enable_provider(provider_name)
      provider = PROVIDER_REGISTRY[provider_name.to_s]
      raise "Unknown provider: #{provider_name}" unless provider

      provider.enabled = true
    end

    ##@@ TODO add spec for this
    def self.add_model(provider_name, model_name, **details)
      executor_class_name = details[:executor]
      provider = register_provider(
        provider_name, executor_class_name,
        **details.slice(:base_url, :api_key_env_var, :exclude_params)
      )
      register_model(
        provider.provider_name, model_name,
        **details.slice(:pricing, :tools, :vision, :thinking, :enabled, :aliases)
      )
    end

    def self.load_models_file(file_path)
      JSON.parse(File.read(file_path)).each do |provider_name, info|
        executor_class_name = info['executor']
        params = info.slice('base_url', 'api_key_env_var', 'tools', 'vision', 'thinking', 'enabled', 'exclude_params').transform_keys(&:to_sym)
        register_provider(provider_name, executor_class_name, **params)

        info['models'].each do |model_name, model_info|
          params = model_info.slice('pricing', 'tools', 'vision', 'thinking', 'enabled', 'aliases').transform_keys(&:to_sym)
          register_model(provider_name, model_name, **params)
        end
      end
    end

    load_models_file(File.join(File.dirname(__FILE__), 'public_models.json'))

    def self.find_model(model_name, include_disabled = false)
      lookup_model_name = (ALIAS_REGISTRY[model_name] || model_name).to_s

      candidate_providers = MODEL_TO_PROVIDER_REGISTRY[lookup_model_name].to_a

      if 1 == candidate_providers.size
        find_model_for_provider(candidate_providers[0], lookup_model_name, include_disabled)
      elsif candidate_providers.size > 1
        raise "Multiple providers match #{model_name}: #{candidate_providers.join(', ')}"
      else
        if model_name.include?(':')
          provider_part, model_name_part = model_name.split(':', 2)
          find_model_for_provider(provider_part, model_name_part, include_disabled)
        else
          nil
        end
      end
    end

    def self.find_model_for_provider(provider_name, model_name, include_disabled = false)
      provider = PROVIDER_REGISTRY[provider_name.to_s]
      raise "Unknown provider: #{provider_name}" unless provider

      return nil unless provider.is_enabled? || include_disabled

      model = PROVIDER_TO_MODEL_REGISTRY[provider.provider_name][model_name]
      if !model.nil? && (model.is_enabled? || include_disabled)
        model
      else
        nil
      end
    end

    def self.list_model_names(full: true, require_tools: false, require_vision: false, require_thinking: false, include_disabled: false)
      ok_model_names = []
      PROVIDER_REGISTRY.each do |provider_name, provider|
        provider_ok_for_enabled = include_disabled || provider.is_enabled?
        provider_ok_for_tools = !require_tools || provider.possibly_supports_tools?
        provider_ok_for_vision = !require_vision || provider.possibly_supports_vision?
        provider_ok_for_thinking = !require_thinking || provider.possibly_supports_thinking?

        if provider_ok_for_enabled && provider_ok_for_tools && provider_ok_for_vision && provider_ok_for_thinking
          PROVIDER_TO_MODEL_REGISTRY[provider.provider_name].each do |_, model|
            model_ok_for_enabled = include_disabled || model.is_enabled?
            model_ok_for_tools = !require_tools || (model.certainly_supports_tools?)
            model_ok_for_vision = !require_vision || (model.certainly_supports_vision?)
            model_ok_for_thinking = !require_thinking || (model.certainly_supports_thinking?)

            if model_ok_for_enabled && model_ok_for_tools && model_ok_for_vision && model_ok_for_thinking
              if full
                ok_model_names << "#{provider_name}:#{model.model_name}"
              else
                ok_model_names << model.model_name
              end
            end
          end
        end
      end

      ok_model_names.sort
    end

  end
end
