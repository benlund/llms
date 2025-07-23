require_relative './open_ai_compatible_executor'

module LLMs
  module Executors
    ##@@ TODO remove need for this.
    class HuggingFaceExecutor < OpenAICompatibleExecutor

      private

      def initialize_client
        @base_url = "https://api-inference.huggingface.co/models/#{@model_name}/v1"
        super
      end

    end
  end
end
