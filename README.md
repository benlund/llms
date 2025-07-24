# LLMs

A Ruby library for interacting with Large Language Model (LLM) providers including Anthropic, Google Gemini, X.ai, and other OpenAI-compatible API providers (including local models). Supports streaming, tool-use, image input, and cost-tracking.


## Current Version

0.1.0

Just about usable in production.


## Installation

Add to your Gemfile:
```ruby
gem 'llms-rb'
```

Then run:

```bash
bundle install
```

Or install directly:

```bash
gem install llms-rb
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
```

##@@ TODO add an example script with custom model to cehck above example works


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

## Development

After checking out the repo, run `bundle install` to install dependencies. Then, run `rspec` to run the tests.


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/benlund/llms-rb


## License

This gem is available as open source under the terms of the MIT License.
