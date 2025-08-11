local M = {}

-- Provider registry
M.providers = {}
M.current_provider = nil

-- Register a provider
function M.register(name, provider)
  M.providers[name] = provider
end

-- Set current provider
function M.set_provider(name)
  if M.providers[name] then
    M.current_provider = M.providers[name]
    return true
  end
  return false
end

-- Get current provider
function M.get_provider()
  return M.current_provider
end

-- Initialize providers
function M.setup(config)
  -- Load all providers
  require("providers.llama_cpp")
  
  -- Set default provider
  M.set_provider("llama_cpp")
  
  -- TODO: Add Ollama provider support
  -- TODO: Add other providers (OpenAI, Anthropic, etc.)
end

return M
