require 'optparse'
require 'readline'
require_relative '../llms'
require_relative '../llms-tc' ##@@ TOD circular dependency here? fix this


module LLMs
  class CLI

    TEMPERATURE = 0.0

    DEFAULT_OPTIONS = {
      stream: true,
      system_prompt: "You are a helpful assistant",
      model: "claude-3-5-sonnet-latest", 
      max_tokens: 1000,
      tools: true,
      always_execute_tools: false
    }

    def initialize(command_name, override_default_options = {})
      @command_name = command_name
      @options = DEFAULT_OPTIONS.merge(override_default_options)
      parse_options
    end

    def run_chat(executor)
      conversation = LLMs::Conversation.new
      conversation.set_system_message(@options[:system_prompt])
      if @options[:tools]
        conversation.set_available_tools([LLMs::TC::CurlGet])
      end

      # Set up command history
      Readline.completion_append_character = " "
      Readline.completion_proc = proc { |s| [] }

      should_continue = add_user_input(conversation)

      while should_continue
        if @options[:stream]
          executor.execute_conversation(conversation) { |chunk| print chunk }
          puts
        else
          response = executor.execute_conversation(conversation)
          puts response.text
        end

        if error = executor.last_error
          $stderr.puts "Error: #{error.inspect}"
          ## TODO - either exit or remove the last message so we an retry or something
        else
          conversation.add_assistant_message(executor.last_received_message)
          usage = executor.last_usage_data
          $stderr.puts "Usage: #{usage}"
        end

        if executor.last_received_message&.tool_calls&.any?
          tool_calls = executor.last_received_message.tool_calls
          
          puts "Tool calls:"
          tool_calls.each_with_index do |call, i|
            puts "#{i + 1}. #{call.name}(#{call.arguments.inspect})"
          end

          execute = if @options[:always_execute_tools]
            true
          else
            print "\nExecute these tool calls? (y/N) "
            $stdin.gets.chomp.downcase == 'y'
          end

          if execute
            add_tool_results(conversation, tool_calls)
            next
          end
        end

        should_continue = add_user_input(conversation)
      end
    end

    ## TODO make this handle a loop of tools calls too 
    def run_prompt(executor, prompt)
      if @options[:stream]
        executor.execute_prompt(prompt.strip) { |chunk| print chunk }
        puts
      else
        response = executor.execute_prompt(prompt.strip)
        puts response
      end

      if error = executor.last_error
        $stderr.puts "Error: #{error.inspect}"
      end

      usage = executor.last_usage_data
      $stderr.puts "Usage: #{usage}"
    end

    def run
      executor = create_executor
      if ARGV.empty?
        run_chat(executor)
      else
        run_prompt(executor, ARGV.join(' '))
      end
    end

    private

    def parse_options
      OptionParser.new do |opts|
        opts.banner = "Usage: #{@command_name} [options] [PROMPT]"

        opts.on("--no-stream", "Disable streaming output") do
          @options[:stream] = false
        end

        opts.on("--system PROMPT", "Set custom system prompt") do |prompt|
          @options[:system_prompt] = prompt
        end

        opts.on("-m", "--model MODEL", "Specify model name") do |model|
          @options[:model] = model
        end

        opts.on("--max-tokens N", Integer, "Set max tokens (default: 1000)") do |n|
          @options[:max_tokens] = n
        end

        opts.on("--no-tools", "Disable tool usage") do
          @options[:tools] = false
        end

        opts.on("--always-execute-tools", "Always execute tool calls without asking") do
          @options[:always_execute_tools] = true
        end
      end.parse!
    end

    def create_executor
      LLMs::Executors.instance(
        model_name: @options[:model],
        temperature: TEMPERATURE,
        max_tokens: @options[:max_tokens],
        tools: @options[:tools] ? [LLMs::TC::CurlGet] : nil  ##@@ TODO: not working to add the tools 
      )
    end

    def add_user_input(conversation)
      prompt = Readline.readline("> ", true)
      if prompt.nil? || prompt.empty? || prompt == "exit"
        return false
      end
      conversation.add_user_message(prompt)
      true
    end

    def add_tool_results(conversation, tool_calls)
      tool_results = []
      
      tool_calls.each.with_index do |tc, i|
        index =  tc.index || i
        tool_definition = find_tool_definition(tc.name)
        if tool_definition
          begin
            tdi = tool_definition.new(**tc.arguments)                  
            tool_runner = find_tool_runner(tool_definition)
            tool_runner.run(tdi)
            tool_results << LLMs::ConversationMessage::ToolResult.new(
              index,
              tc.tool_call_id,
              tc.tool_call_type,
              tc.name,
              tool_runner.result,
              tool_runner.is_error
            )
          rescue StandardError => e
            tool_results << LLMs::ConversationMessage::ToolResult.new(
              index,
              tc.tool_call_id,
              tc.tool_call_type,
              tc.name,
              "Error running tool: #{e.message}",
              true
            )
          end
        end
      end

      if true #options[:report_tool_results] TODO implement this
        puts "Tool results: #{tool_results.inspect}"
      end

      conversation.add_user_message(nil, tool_results)

      true ##TODO detect error loops and stop
    end

    def find_tool_definition(tool_name)
      ##@@ TODO implemetn this
      if tool_name == "curlget"
        LLMs::TC::CurlGet
      else
        nil
      end
    end

    def find_tool_runner(tool_definition)
      ##@@ TODO implement this
      if tool_definition == LLMs::TC::CurlGet
        LLMs::TC::CurlGetRunner.new
      else
        nil
      end
    end

  end
end

# Example script:
#
# #!/usr/bin/env ruby
# require_relative 'lib/llms'
# require_relative 'lib/llms/cli'
# 
# LLMs::CLI.new.run('command name')
