require_relative 'base'
require 'readline'

module LLMs
  module CLI
    class Chat < Base
      protected

      def default_options
        super.merge({
          stream: true,
          system_prompt: "You are a helpful assistant",
          model_name: LLMs::Models::DEFAULT_MODEL,
          max_completion_tokens: 2048,
          thinking_mode: false,
          thinking_effort: nil,
          max_thinking_tokens: 1024,
          quiet: false
        })
      end

      def add_custom_options(opts)
        opts.on("--no-stream", "Disable streaming output") do
          @options[:stream] = false
        end
        opts.on("--system PROMPT", "Set custom system prompt") do |prompt|
          @options[:system_prompt] = prompt
        end
      end

      def perform_execution
        if ARGV.empty?
          run_chat
        else
          run_prompt(ARGV.join(' '))
        end
      end

      private

      def run_chat
        conversation = LLMs::Conversation.new
        conversation.set_system_message(@options[:system_prompt])

        Readline.completion_append_character = " "
        Readline.completion_proc = proc { |s| [] }

        loop do
          prompt = Readline.readline("> ", true)
          break if prompt.nil? || prompt.empty? || prompt == "exit"

          conversation.add_user_message(prompt)

          if @options[:stream]
            @executor.execute_conversation(conversation) { |chunk| print chunk }
            puts
          else
            response = @executor.execute_conversation(conversation)
            puts response.text
          end

          if error = @executor.last_error
            $stderr.puts "Error: #{error.inspect}"
          end

          unless @options[:quiet]
            usage = @executor.last_usage_data
            puts "Usage: #{usage}"
          end

          conversation.add_assistant_message(@executor.last_received_message)
        end
      end

      def run_prompt(prompt)
        if @options[:stream]
          @executor.execute_prompt(prompt.strip) { |chunk| print chunk }
          puts
        else
          response = @executor.execute_prompt(prompt.strip)
          puts response
        end

        if error = @executor.last_error
          $stderr.puts "Error: #{error.inspect}"
        end

        report_usage(executor)
      end
    end
  end
end
