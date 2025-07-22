require_relative 'base'
require_relative '../conversation'

module LLMs
  module CLI
    class TestToolUse < Base
      class CalculatorTool
        def self.tool_schema
          {
            name: 'calculator_tool',
            description: 'Compute a plain-text arithmetic calculation using the operators + - * / and parens (). E.g. (2 + 2) / (3 - 1)',
            parameters: {
              properties: {
                calculation: {
                  type: 'string',
                  description: 'The arithmetic operation to perform'
                },
              },
              type: 'object',
            }
          }
        end
      end

      protected

      def default_options
        super.merge({
          max_completion_tokens: 250,
          prompt: "2+2=",
          system_prompt: "Always reply with a tool use function call"
        })
      end

      def add_custom_options(opts)
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
          cm = LLMs::Conversation.new
          cm.set_system_message(@options[:system_prompt])
          cm.set_available_tools([CalculatorTool])
          cm.add_user_message(@options[:prompt])

          if @options[:stream]
            print "#{executor.model_name}: "
            executor.execute_conversation(cm) do |chunk|
              print chunk
            end
            puts
          else
            response_message = executor.execute_conversation(cm)
            puts "#{executor.model_name}: #{response_message&.text}"
          end

          # Display tool calls if present
          if executor.last_received_message&.tool_calls
            puts 'Tool calls: ' + executor.last_received_message.tool_calls.map { |tc| "#{tc.name}: #{tc.arguments} - #{tc.tool_call_id}" }.join(', ')
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
        models = LLMs::Models.list_model_names(full: true, require_tools: true)

        # Filter by model name if provided
        if ARGV[0]
          models = models.select { |name| name.include?(ARGV[0]) }
        end

        models
      end
    end
  end
end
