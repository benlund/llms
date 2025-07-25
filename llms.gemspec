Gem::Specification.new do |spec|
  spec.name          = "llms"
  spec.version       = "0.1.0"
  spec.authors       = ["Ben Lund"]
  spec.email         = ["ben@benlund.com"]

  spec.summary       = "Ruby library for using LLM APIs across multiple providers"

  spec.description   = "Ruby library for interacting with various LLM providers including Anthropic, Google Gemini, xAI, and other OpenAI-compatible API providers (including local models). Supports streaming, event-handling, conversation management, tool-use, image input, and cost-tracking."
  spec.homepage      = "https://github.com/benlund/llms"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 2.5.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.glob("{bin,lib}/**/*") + %w[README.md LICENSE]
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "ruby-anthropic", "~> 0.4.2"
  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "json", "~> 2.0"
  spec.add_dependency "readline", "~> 0.0"
  spec.add_dependency "base64", ">= 0.1"

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "yard", "~> 0.9"
  spec.add_development_dependency "rubocop", "~> 1.0"
end
