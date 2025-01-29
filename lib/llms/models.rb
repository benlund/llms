require 'json'

module LLMs
  module Models
    MODEL_REGISTRY = {}
    MODEL_NAMES = {
      full: {},
      short: {}
    }

    def self.register_model(provider, model, pricing)
      provider_sym = provider.to_sym

      MODEL_REGISTRY[provider_sym][:models][model] ||= {}
      MODEL_REGISTRY[provider_sym][:models][model] = {
        model_name: model,
        pricing: pricing,
        enabled: true
      }

      MODEL_NAMES[:short][model] ||= []
      if MODEL_NAMES[:short][model].include?(provider_sym)
        raise "Error registering model: duplicate name #{model} for provider #{provider}"
      else
        MODEL_NAMES[:short][model] << provider_sym
      end

      MODEL_NAMES[:full]["#{provider}/#{model}"] ||= []
      MODEL_NAMES[:full]["#{provider}/#{model}"] << provider_sym
    end

    def self.register_models(provider, info)
      unless MODEL_REGISTRY[provider.to_sym]
        register_provider(provider, info[:executor], info[:connection], info[:enabled])
      end

      info[:models].each do |model, pricing|
        register_model(provider, model, pricing.transform_keys(&:to_sym))
      end
    end

    def self.register_provider(provider, executor, connection_info, enabled)
      raise ArgumentError, "executor can't be nil" if executor.nil?
      raise ArgumentError, "enabled can't be nil" if enabled.nil?

      MODEL_REGISTRY[provider.to_sym] ||= {}
      MODEL_REGISTRY[provider.to_sym] = {
        executor: executor,
        connection: connection_info.transform_keys(&:to_sym),
        models: {},
        enabled: enabled
      }
    end

    def self.disable_model(provider, model_name)
      MODEL_REGISTRY[provider.to_sym][:models][model_name][:enabled] = false
    end

    def self.disable_provider(provider)
      MODEL_REGISTRY[provider.to_sym][:enabled] = false
    end

    def self.enable_provider(provider)
      MODEL_REGISTRY[provider.to_sym][:enabled] = true
    end

    def self.load_models_file(file_path)
      JSON.parse(File.read(file_path)).each do |provider, info|
        provider = provider.to_sym
        info = info.transform_keys(&:to_sym)
        if MODEL_REGISTRY[provider].nil?
          register_models(provider, info)
        elsif info[:enabled] == false
          disable_provider(provider)
        elsif info[:enabled] == true
          enable_provider(provider)
        else
          ##@@ TODO add ability to disable individual models ??
          raise "Provider exists #{provider} - don't know what to do with #{info} in #{file_path}" ##@@ TODO fixme
        end
      end
    end

    load_models_file(File.join(File.dirname(__FILE__), 'public_models.json'))

    def self.find_model_info(model_name, include_disabled = false)
      candidate_providers = ( (MODEL_NAMES[:full][model_name] || []) +
                              (MODEL_NAMES[:short][model_name] || []) ).uniq

      if 1 == candidate_providers.size
        provider = candidate_providers[0]
        provider_info = MODEL_REGISTRY[provider.to_sym]

        if provider_info[:enabled] || include_disabled
          short_model_name = model_name.start_with?("#{provider}/") ? model_name[(provider.to_s.size+1)..-1] : model_name
          if model_info = provider_info[:models][short_model_name]
            if model_info[:enabled] || include_disabled
              return model_info.merge(provider_info.slice(:executor, :connection, :enabled))
            end
          end
        end
      elsif candidate_providers.size > 1
        $stderr.puts "Multiple providers match #{model_name}: #{candidate_providers.join(', ')}"
      end

      nil
    end

    def self.list_model_names(full: true, include_disabled: false)
      MODEL_REGISTRY.select do |provider, info|
        info[:enabled] || include_disabled
      end.flat_map do |provider, info|
        info[:models].select { |_, model_info| model_info[:enabled] || include_disabled }.keys.map do |short_name|
          if full
            "#{provider}/#{short_name}"
          else
            short_name
          end
        end
      end.sort
    end

    def self.model_name_exists?(model_name)
      !find_model_info(model_name).nil?
    end

    def self.search_model_names(model_name_substring)
      list_model_names.select do |model_name|
        model_name.include?(model_name_substring)
      end
    end

  end
end
