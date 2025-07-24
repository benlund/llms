# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-07-25

### Added
- Initial release of llms-rb gem
- Support for multiple LLM providers
  - Anthropic
  - Google Gemini
  - xAI
  - Any OpenAI Compatible provider
  - Cerebras
  - Fireworks
  - Deepinfra (disablesd by default)
  - Novita (disabled by default)
  - HuggingFace (executor implemetation only)
- Streaming response support
- Event-handling
- Tool usage and function calling
- Image processing capabilities
- Cost tracking and usage reporting
- Prompt caching support
- CLI tools for testing and interaction
- Basic test suite with RSpec
