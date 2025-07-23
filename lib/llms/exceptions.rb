module LLMs
  # Base exception class for all LLMs errors
  class Error < StandardError; end

  # Configuration errors
  class ConfigurationError < Error; end
  class MissingAPIKeyError < ConfigurationError; end
  class InvalidModelError < ConfigurationError; end
  class UnsupportedFeatureError < ConfigurationError; end
  class ModelNotFoundError < ConfigurationError; end
  class ProviderNotFoundError < ConfigurationError; end

  # API communication errors
  class APIError < Error; end
  class RateLimitError < APIError; end
  class TimeoutError < APIError; end
  class NetworkError < APIError; end
  class AuthenticationError < APIError; end

  # Usage and cost calculation errors
  class UsageError < Error; end
  class CostCalculationError < UsageError; end

  # Tool-related errors
  class ToolError < Error; end
  class ToolExecutionError < ToolError; end
  class ToolValidationError < ToolError; end

  # Conversation and message errors
  class ConversationError < Error; end
  class MessageError < ConversationError; end
  class InvalidMessageRoleError < MessageError; end
end 