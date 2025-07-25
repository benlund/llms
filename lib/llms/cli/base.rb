require 'optparse'

module LLMs
  module CLI
    class Base
      attr_reader :options, :executor

      def initialize(command_name, override_default_options = {})
        @command_name = command_name
        @options = default_options.merge(override_default_options)
        parse_options
      end

      def run
        setup
        execute
        cleanup
      rescue LLMs::Error => e
        $stderr.puts "Error: #{e.message}"
        exit 1
      rescue StandardError => e
        $stderr.puts "Unexpected error: #{e.message}"
        if @options[:debug]
          $stderr.puts e.backtrace
        end
        exit 1
      end

      protected

      def default_options
        {
          stream: false,
          usage: false,
          quiet: false,
          debug: false,
          model_name: nil,
          list_models: false,
          max_completion_tokens: nil,
          max_thinking_tokens: nil,
          thinking_effort: nil,
          thinking_mode: false,
          temperature: 0.0,
          oac_base_url: nil,
          oac_api_key: nil,
          oac_api_key_env_var: nil
        }
      end

      def parse_options
        OptionParser.new do |opts|
          opts.banner = "Usage: #{@command_name} [options]"

          opts.on("--system PROMPT", "Set custom system prompt") do |prompt|
            @options[:system_prompt] = prompt
          end

          opts.on("--stream", "Stream the output") do
            @options[:stream] = true
          end

          opts.on("--usage", "Show usage information") do
            @options[:usage] = true
          end

          opts.on("-q", "--quiet", "Suppress non-essential output") do
            @options[:quiet] = true
          end

          opts.on("-d", "--debug", "Enable debug output") do
            @options[:debug] = true
          end

          opts.on("-m", "--model MODEL", "Specify model name") do |model|
            @options[:model_name] = model
          end

          opts.on("-l", "--list-models", "List available models") do
            @options[:list_models] = true
          end

          opts.on("--max-completion-tokens N", Integer, "Set max completion tokens") do |n|
            @options[:max_completion_tokens] = n
          end

          opts.on("--max-thinking-tokens N", Integer, "Set max thinking tokens") do |n|
            @options[:max_thinking_tokens] = n
          end

          opts.on("--thinking-effort L", "Set thinking effort (low, medium, high)") do |level|
            @options[:thinking_effort] = level
          end

          opts.on("-t", "--thinking", "Enable thinking mode") do
            @options[:thinking_mode] = true
          end

          opts.on("--temperature T", Float, "Set temperature") do |t|
            @options[:temperature] = t
          end

          opts.on("--oac-base-url URL", "OpenAI Compatible base URL to use") do |url|
            @options[:oac_base_url] = url
          end

          opts.on("--oac-api-key KEY", "OpenAI Compatible API key to use") do |key|
            @options[:oac_api_key] = key
          end

          opts.on("--oac-api-key-env-var VAR", "OpenAI Compatible API key environment variable to use") do |var|
            @options[:oac_api_key_env_var] = var
          end

          add_custom_options(opts)
        end.parse!
      end

      def add_custom_options(opts)
        # Override in subclasses to add custom options
      end

      def setup
        validate_options
        set_executor unless @options[:list_models]
      end

      def execute
        if @options[:list_models]
          list_models
        else
          perform_execution
        end
      end

      def cleanup
        # Override in subclasses if needed
      end

      def validate_options
        raise LLMs::ConfigurationError, "Model name is required" if @options[:model_name].nil? && !@options[:list_models]
      end

      def set_executor
        @executor = create_executor
      end

      def create_executor(options_override = {})
        executor = LLMs::Executors.instance(**@options.merge(options_override))

        unless @options.merge(options_override)[:quiet]
          puts "Connected to: #{executor.model_name} (#{executor.class.name}#{executor.base_url ? " #{executor.base_url}" : ""})"
        end

        executor
      end

      def list_models
        models = LLMs::Models.list_model_names(full: true)
        if @options[:model]
          models = models.select { |name| name.include?(@options[:model]) }
        end
        puts models
      end

      def perform_execution
        raise NotImplementedError, "Subclasses must implement perform_execution"
      end

      def report_usage(executor)
        return if @options[:quiet] || !@options[:usage]

        if usage = executor.last_usage_data
          puts usage.inspect
        end
      end

      def report_error(executor)
        return if @options[:quiet]

        if error = executor.last_error
          $stderr.puts "Error: #{error.inspect}"
        end
      end
    end
  end
end
