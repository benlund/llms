require_relative 'models'
require_relative 'executors/base_executor'
require_relative 'executors/anthropic_executor'
require_relative 'executors/google_gemini_executor'
require_relative 'executors/open_ai_compatible_executor'
require_relative 'executors/hugging_face_executor'

module LLMs
  module Executors

    def self.instance(**params)
      model_name = params[:model_name]
      raise ArgumentError, "No model name provided" if model_name.nil?

      executor_class = nil
      base_url = nil
      api_key = params[:api_key]
      api_key_env_var = params[:api_key_env_var]
      pricing = params[:pricing]
      exclude_params = params[:exclude_params]

      if params[:oac_base_url]
        executor_class = OpenAICompatibleExecutor
        base_url = params[:oac_base_url]
        api_key = params[:oac_api_key]
        api_key_env_var = params[:oac_api_key_env_var]
      else
        model = Models.find_model(model_name)
        raise ArgumentError, "Unknown model: #{model_name}" if model.nil?

        model_name = model.model_name
        executor_class = LLMs::Executors.const_get(model.provider.executor_class_name)
        base_url = model.provider.base_url
        api_key_env_var = model.provider.api_key_env_var
        pricing = model.pricing
        exclude_params = model.provider.exclude_params
      end

      init_params = params.merge(
        model_name:,
        base_url:,
        api_key:,
        api_key_env_var:,
        pricing:,
        exclude_params:
      )

      executor_class.new(**init_params)
    end

  end
end
