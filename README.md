# LLMs

A Ruby library for interacting with Large Language Model (LLM) providers including Anthropic, Google Gemini, X.ai, and other OpenAI-compatible API providers (including local models).

Supports streaming, event-handling, conversation management, tool-use, image input, and cost-tracking.


## Current Version

0.1.0

Just about usable in production.

[Released 2025-07-25 on Rubygems](https://rubygems.org/gems/llms)


## Installation

Add to your Gemfile:
```ruby
gem 'llms'
```

Then run:

```bash
bundle install
```

Or install directly:

```bash
gem install llms
```

## Quick Start

```ruby
require 'llms'

# Create an executor for a specific model
executor = LLMs::Executors.instance(
  model_name: 'claude-sonnet-4-0',
  temperature: 0.0,
  max_completion_tokens: 1000
)

# Simple prompt execution
puts executor.execute_prompt("What is 2+2?")

# Streaming response
executor.execute_prompt("What is the airspeed velocitty of an unladen swallow?") do |chunk|
  print chunk
end

# Simple Chat
conversation = LLMs::Conversation.new
while true
  print "> "
  conversation.add_user_message($stdin.gets)
  response = executor.execute_conversation(conversation){|chunk| print chunk}
  puts
  conversation.add_assistant_message(response)
end

# Add a custom model
LLMs::Models.add_model('ollama', 'qwen3:8b',
  executor: 'OpenAICompatibleExecutor', base_url: 'http://localhost:11434/api')

executor = LLMs::Executors.instance(model_name: 'qwen3:8b', api_key: 'none')
puts executor.execute_prompt("What is 2+2?")

# Handle Streaming Events

executor.stream_conversation(conversation) do |emitter|
  emitter.on :tool_call_completed do |event|
    puts event.name
    puts event.arguments.inspect
  end
end
```

## Supported Models

LLMs from Anthropic, Google, xAI, and various open-weight inference hosts are pre-configured in this release. See `lib/llms/public_models.json` for the full list. No models from OpenAI are pre-configured but you can set them up them manually in your application code along the lines of the exmaple above.


## Configuration

Set your API keys as environment variables:

```bash
export ANTHROPIC_API_KEY="your-anthropic-key"
export GOOGLE_GEMINI_API_KEY="your-gemini-key"
```

See lib/public_models.json for supported providers and their corresponding API key env vars.

Or pass to directly into Executor initialization:

```ruby

require 'llms'

executor = LLMs::Executors::AnthropicExecutor.new(
  model_name: 'claude-sonnet-4-0',
  temperature: 0.0,
  max_completion_tokens: 1000,
  api_key: 'api-key-here'
)
```



## CLI Usage

### Interactive Chat

```bash
llms-chat --model model-name
```

or if model-name would be ambiguous:

```bash
llms-chat --model provider:model-name
```

or to run against a local model (e.g. LMStudio):

```bash
llms-chat --oac-base-url "http://127.0.0.1:1234/v1" -m qwen/qwen3-32b --oac-api-key none
```

### List Available Models

```bash
llms-chat --list-models
```

### Test various features against all models

```bash
llms-test-model-access # send a short question with a custom system prompt to all models in turn
llms-test-model-tool-usage # configures a simple tool and asks all models in turn to call it
llms-test-model-image-support # sends an image to every model asking it to describe the image
llms-test-prompt-caching # send a long prompt and see if it is cached
```

## Development

After checking out the repo, run `bundle install` to install dependencies. Then, run `rspec` to run the tests.


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/benlund/llms


## License

This gem is available as open source under the terms of the MIT License.
