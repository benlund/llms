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

      model_info = Models.find_model_info(model_name)
      raise ArgumentError, "Unknown model: #{model_name}" if model_info.nil?

      executor_class = const_get(model_info[:executor])
      init_params = params.merge(
        model_name: model_info[:model_name],
        model_info: model_info.slice(:connection, :pricing))

      executor_class.new(**init_params)
    end
  end
end
