require 'json'

module LLMs
  module Models
    MODEL_REGISTRY = {}
    MODEL_PROVIDERS = {}

    def self.register_model(provider, model, pricing, tools: nil, enabled: true)
      provider_sym = provider.to_sym
      raise "Unknown provider: #{provider_sym}" unless MODEL_REGISTRY.key?(provider_sym)

      MODEL_REGISTRY[provider_sym][:models][model] ||= {}
      MODEL_REGISTRY[provider_sym][:models][model] = {
        model_name: model,
        pricing: pricing.transform_keys(&:to_sym),
        tools: tools,
        enabled: !!enabled
      }

      MODEL_PROVIDERS[model] ||= Set.new
      MODEL_PROVIDERS[model] << provider_sym

      model
    end

    def self.register_models(provider, models)
      models.each do |model, info|
        mi = info.transform_keys(&:to_sym)
        pricing = mi.slice(:input, :output) ##@@ TODO cache info here too
        tools = mi[:tools]
        enabled = mi.key?(:enabled) ? mi[:enabled] : true
        register_model(provider, model, pricing, tools:, enabled:)
      end
    end

    def self.register_provider(provider, executor, connection_info, tools: nil, enabled: true)
      raise ArgumentError, "executor can't be nil" if executor.nil?
      raise ArgumentError, "connection_info can't be nil" if connection_info.nil?

      MODEL_REGISTRY[provider.to_sym] ||= {}
      MODEL_REGISTRY[provider.to_sym] = {
        executor: executor,
        connection: connection_info.transform_keys(&:to_sym),
        models: {},
        tools: tools,
        enabled: !!enabled
      }
    end

    def self.disable_model(provider, model_name)
      MODEL_REGISTRY[provider.to_sym][:models][model_name][:enabled] = false
    end

    def self.enable_model(provider, model_name)
      MODEL_REGISTRY[provider.to_sym][:models][model_name][:enabled] = true
    end

    def self.disable_provider(provider)
      MODEL_REGISTRY[provider.to_sym][:enabled] = false
    end

    def self.enable_provider(provider)
      MODEL_REGISTRY[provider.to_sym][:enabled] = true
    end

    ##@@ TODO fix and simplify
    def self.load_models_file(file_path)
      JSON.parse(File.read(file_path)).each do |provider, info|
        register_provider(provider, info['executor'], info['connection'], tools: info['tools'], enabled: info['enabled'])
        register_models(provider, info['models'])
      end
    end

    load_models_file(File.join(File.dirname(__FILE__), 'public_models.json'))

    def self.find_model_info(model_name, include_disabled = false)
      candidate_providers = MODEL_PROVIDERS[model_name].to_a

      if 1 == candidate_providers.size
        find_model_info_for_provider(candidate_providers[0], model_name, include_disabled)
      elsif candidate_providers.size > 1
        raise "Multiple providers match #{model_name}: #{candidate_providers.join(', ')}"
      else
        if model_name.include?(':')
          provider_part, model_name_part = model_name.split(':', 2)
          find_model_info_for_provider(provider_part, model_name_part, include_disabled)
        else
          nil
        end
      end
    end

    def self.find_model_info_for_provider(provider, model_name, include_disabled = false)
      provider_sym = provider.to_sym
      raise "Unknown provider: #{provider_sym}" unless MODEL_REGISTRY.key?(provider_sym)

      provider_info = MODEL_REGISTRY[provider_sym]

      if provider_info[:enabled] || include_disabled
        if model_info = provider_info[:models][model_name]
          if model_info[:enabled] || include_disabled
            return model_info.merge(provider_info.slice(:executor, :connection, :enabled))
          end
        end
      end

      nil
    end

    def self.list_model_names(full: true, require_tools: false, include_disabled: false)
      MODEL_REGISTRY.select do |provider, info|
        (info[:enabled] || include_disabled) && (!require_tools || (info[:tools] != false))
      end.flat_map do |provider, info|
        info[:models].select do |_, model_info|
          (model_info[:enabled] || include_disabled) && (!require_tools || (model_info[:tools] != false))
        end.keys.map do |short_name|
          if full
            "#{provider}:#{short_name}"
          else
            short_name
          end
        end
      end.sort
    end

    def self.model_name_exists?(model_name)
      begin
        !find_model_info(model_name).nil?
      rescue StandardError => e
        false
      end
    end

    def self.search_model_names(model_name_substring, include_disabled: false)
      list_model_names(include_disabled:).select do |model_name|
        model_name.include?(model_name_substring)
      end
    end

  end
end
