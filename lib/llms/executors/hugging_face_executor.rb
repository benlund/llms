require_relative './open_ai_compatible_executor'

module LLMs
  module Executors
    class HuggingFaceExecutor < OpenAICompatibleExecutor

      private

      ## TODO remove need for this class (by supporting e.g. a base_url_template param?)
      def initialize_client
        @base_url = "https://api-inference.huggingface.co/models/#{@model_name}/v1"
        super
      end

    end
  end
end
