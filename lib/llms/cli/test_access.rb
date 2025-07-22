require_relative 'base'

module LLMs
  module CLI
    class TestAccess < Base
      protected

      def default_options
        super.merge({
          max_completion_tokens: 250,
          latest: false,
          prompt: "2+2=",
          system_prompt: "Always reply with numbers as WORDS not digits."
        })
      end

      def add_custom_options(opts)
        opts.on("--latest", "Only test latest releases in each class from each provider") do
          @options[:latest] = true
        end

        opts.on("--prompt PROMPT", "Test prompt to use") do |prompt|
          @options[:prompt] = prompt
        end
      end

      def setup
        # No model name required for this command - TODO make configurable
        true
      end

      def perform_execution
        if @options[:model_name]
          test_single_model(create_executor({quiet: true}))
        else
          test_all_models
        end
      end

      private

      def test_single_model(executor)
        begin
          if @options[:stream]
            print "#{executor.model_name}: "
            response = executor.execute_prompt(@options[:prompt], system_prompt: @options[:system_prompt]) do |chunk|
              print chunk
            end
            puts
          else
            response = executor.execute_prompt(@options[:prompt], system_prompt: @options[:system_prompt])
            puts "#{executor.model_name}: #{response}"
          end

          report_error(executor)
          report_usage(executor)

        rescue => e
          puts "#{executor.model_name}: ERROR - #{e.message}"
          puts e.backtrace if @options[:debug]
        end
      end

      def test_all_models
        models = get_models_to_test

        models.each do |model_name|
          test_single_model(create_executor({model_name: model_name, quiet: true}))
          puts "-" * 80
        end
      end

      def get_models_to_test
        models = LLMs::Models.list_model_names(full: true)

        # Filter by latest if requested
        if @options[:latest]
          # TODO: Implement latest filtering logic
          # For now, just use all models
        end

        # Filter by model name if provided
        if ARGV[0]
          models = models.select { |name| name.include?(ARGV[0]) }
        end

        models
      end
    end
  end
end
