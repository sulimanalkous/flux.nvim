local BaseProvider = require("providers.base")
local api = vim.api

local M = {}

-- LlamaCPP provider implementation
function M:new(config)
  local provider = BaseProvider:new(config)
  setmetatable(provider, { __index = M })
  
  -- Default configuration
  provider.config = vim.tbl_extend("force", {
    host = "localhost",
    port = 1234,
    embedding_host = "localhost", 
    embedding_port = 1235,
    embedding_model = "text-embedding"
  }, config or {})
  
  return provider
end

-- Generate a single response
function M:generate(prompt, callback)
  local url = string.format("http://%s:%d/v1/chat/completions", self.config.host, self.config.port)
  
  local data = {
    model = "llama",
    messages = {
      { role = "user", content = prompt }
    },
    stream = false
  }
  
  local json_data = vim.fn.json_encode(data)
  
  local job_id = vim.fn.jobstart({
    "curl", "-s", "-X", "POST", url,
    "-H", "Content-Type: application/json",
    "-d", json_data
  }, {
    on_stdout = function(_, data, _)
      if data and #data > 0 then
        local response = table.concat(data, "")
        local success, result = pcall(vim.fn.json_decode, response)
        if success and result.choices and result.choices[1] then
          callback(result.choices[1].message.content, nil)
        else
          callback(nil, "Failed to parse response")
        end
      else
        callback(nil, "No response received")
      end
    end,
    on_stderr = function(_, data, _)
      local error_msg = table.concat(data, "")
      callback(nil, "Request failed: " .. error_msg)
    end
  })
  
  if job_id <= 0 then
    callback(nil, "Failed to start request")
  end
end

-- Stream response chunks
function M:stream(prompt, on_chunk, on_complete)
  local url = string.format("http://%s:%d/v1/chat/completions", self.config.host, self.config.port)
  
  local data = {
    model = "llama",
    messages = {
      { role = "user", content = prompt }
    },
    stream = true
  }
  
  local json_data = vim.fn.json_encode(data)
  local full_response = ""
  
  local job_id = vim.fn.jobstart({
    "curl", "-s", "-X", "POST", url,
    "-H", "Content-Type: application/json",
    "-d", json_data
  }, {
    on_stdout = function(_, data, _)
      if data and #data > 0 then
        for _, line in ipairs(data) do
          if line:match("^data: ") then
            local json_str = line:sub(7) -- Remove "data: "
            if json_str ~= "[DONE]" then
              local success, result = pcall(vim.fn.json_decode, json_str)
              if success and result.choices and result.choices[1] and result.choices[1].delta and result.choices[1].delta.content then
                local chunk = result.choices[1].delta.content
                full_response = full_response .. chunk
                on_chunk(chunk)
              end
            else
              on_complete(true, nil)
              return
            end
          end
        end
      end
    end,
    on_stderr = function(_, data, _)
      local error_msg = table.concat(data, "")
      on_complete(false, "Request failed: " .. error_msg)
    end
  })
  
  if job_id <= 0 then
    on_complete(false, "Failed to start request")
  end
end

-- Generate embeddings
function M:embed(text, callback)
  local url = string.format("http://%s:%d/v1/embeddings", self.config.embedding_host, self.config.embedding_port)
  
  local data = {
    model = self.config.embedding_model,
    input = text
  }
  
  local json_data = vim.fn.json_encode(data)
  
  local job_id = vim.fn.jobstart({
    "curl", "-s", "-X", "POST", url,
    "-H", "Content-Type: application/json",
    "-d", json_data
  }, {
    on_stdout = function(_, data, _)
      if data and #data > 0 then
        local response = table.concat(data, "")
        local success, result = pcall(vim.fn.json_decode, response)
        if success and result.data and result.data[1] and result.data[1].embedding then
          callback(result.data[1].embedding, nil)
        else
          callback(nil, "Failed to parse embedding response")
        end
      else
        callback(nil, "No embedding response received")
      end
    end,
    on_stderr = function(_, data, _)
      local error_msg = table.concat(data, "")
      callback(nil, "Embedding request failed: " .. error_msg)
    end
  })
  
  if job_id <= 0 then
    callback(nil, "Failed to start embedding request")
  end
end

-- Check if provider supports RAG
function M:supports_rag()
  return true -- llama.cpp supports embeddings
end

-- Get provider name
function M:get_name()
  return "llama_cpp"
end

-- Validate configuration
function M:validate_config()
  -- Basic validation
  if not self.config.host or not self.config.port then
    return false, "Missing host or port configuration"
  end
  if not self.config.embedding_host or not self.config.embedding_port then
    return false, "Missing embedding host or port configuration"
  end
  return true
end

-- Register the provider
local providers = require("providers")
providers.register("llama_cpp", M)

return M
