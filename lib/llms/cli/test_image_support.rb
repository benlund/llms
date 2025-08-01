require_relative 'base'
require 'open-uri'
require 'base64'
require_relative '../conversation'

module LLMs
  module CLI
    class TestImageSupport < Base
      protected

      def default_options
        super.merge({
          max_completion_tokens: 2000,
          prompt: "What is in this picture?",
          system_prompt: "Always reply in Latin"
        })
      end

      def add_custom_options(opts)
        opts.on("--prompt PROMPT", "Test prompt to use") do |prompt|
          @options[:prompt] = prompt
        end
      end

      def setup
        # No model name required for this command
        true
      end

      def perform_execution
        if @options[:model_name]
          test_single_model(create_executor)
        else
          test_all_models
        end
      end

      private

      def test_single_model(executor)
        begin
          image_data = fetch_image_data

          cm = LLMs::Conversation.new
          cm.set_system_message(@options[:system_prompt])
          cm.add_user_message([{ text: @options[:prompt], image: image_data, media_type: 'image/png' }])

          if @options[:stream]
            executor.execute_conversation(cm) do |chunk|
              print chunk
            end
            puts
          else
            response_message = executor.execute_conversation(cm)
            puts response_message&.text
          end

          report_error(executor)
          report_usage(executor)

        rescue StandardError => e
          puts "#{executor.model_name}: ERROR - #{e.message}"
          puts e.backtrace if @options[:debug]
        end
      end

      def test_all_models
        models = get_models_to_test

        models.each do |model_name|
          test_single_model(create_executor({model_name: model_name}))
          puts "-" * 80
        end
      end

      def get_models_to_test
        models = LLMs::Models.list_model_names(full: true, require_vision: true)

        # Filter by model name if provided
        if ARGV[0]
          models = models.select { |name| name.include?(ARGV[0]) }
        end

        models
      end

      def fetch_image_data
        Base64.strict_encode64(URI.open('https://www.google.com/images/branding/googlelogo/1x/googlelogo_color_272x92dp.png').read)
      end
    end
  end
end
