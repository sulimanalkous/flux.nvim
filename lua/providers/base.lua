local M = {}

-- Base provider class
function M:new(config)
  local provider = setmetatable({}, { __index = M })
  provider.config = config or {}
  return provider
end

-- Generate a single response (non-streaming)
function M:generate(prompt, callback)
  error("generate() must be implemented by provider")
end

-- Stream response chunks
function M:stream(prompt, on_chunk, on_complete)
  error("stream() must be implemented by provider")
end

-- Generate embeddings
function M:embed(text, callback)
  error("embed() must be implemented by provider")
end

-- Check if provider supports RAG
function M:supports_rag()
  return false
end

-- Get available models
function M:get_models()
  return {}
end

-- Get provider name
function M:get_name()
  return "base"
end

-- Validate configuration
function M:validate_config()
  return true
end

-- Initialize provider
function M:init()
  -- Override in subclasses if needed
end

-- Cleanup provider
function M:cleanup()
  -- Override in subclasses if needed
end

return M
