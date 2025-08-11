-- Simple LLM functions using your llama-server
local M = {}

local progress = require("ui.progress")
local error_handler = require("ui.error_handler")

-- ---
-- -- Streaming Request Logic
-- ---

-- Raw streaming request function
local function ask_llama_raw_stream(prompt, on_chunk, on_finish)
  local config = require("flux").config
  local payload = {
    messages = {
      { role = "user", content = prompt }
    },
    temperature = 0.1,
    max_tokens = 8192,
    stream = true, -- Enable streaming
  }

  local temp_file = vim.fn.tempname()
  local file = io.open(temp_file, "w")
  if not file then
    if on_finish then on_finish(false, "Failed to create temp file") end
    return
  end

  file:write(vim.json.encode(payload))
  file:close()

  local url = string.format("http://%s:%d/v1/chat/completions", config.host, config.port)
  -- Added --no-buffer for streaming
  local curl_cmd = string.format('curl -s --no-buffer %s -H "Content-Type: application/json" -d @%s', url, temp_file)

  vim.fn.jobstart(curl_cmd, {
    on_stdout = function(_, data)
      if not data then return end
      for _, line in ipairs(data) do
        -- SSE format is "data: {...}"
        if line:match("^data:") then
          local json_str = line:match("^data: (.*)")
          if json_str and json_str ~= "[DONE]" then
            local ok, json = pcall(vim.json.decode, json_str)
            if ok and json.choices and #json.choices > 0 then
              local text_chunk = json.choices[1].delta.content
              if text_chunk and text_chunk ~= vim.NIL then -- Check if it exists and is not vim.NIL
                text_chunk = tostring(text_chunk) -- Explicitly convert to string
                if text_chunk ~= "" and text_chunk ~= "vim.NIL" then -- Check if it's not empty and not vim.NIL string
                  on_chunk(text_chunk)
                end
              end
            end
          end
        end
      end
    end,
    on_stderr = function(_, data)
      if data and #data > 0 and data[1] ~= "" then
        vim.notify("LLM stderr: " .. table.concat(data, "\n"), vim.log.levels.WARN)
      end
    end,
    on_exit = function(_, exit_code)
      vim.fn.delete(temp_file) -- Clean up temp file
      if on_finish then
        on_finish(exit_code == 0, "Request finished with code: " .. tostring(exit_code))
      end
    end,
  })
end

-- Wrapper for streaming requests with retry logic
function M.ask_llama_stream(prompt, on_chunk, on_finish)
  local retries = 3
  local delay = 1000
  local attempts = 0

  local function try()
    attempts = attempts + 1
    
    ask_llama_raw_stream(prompt, on_chunk, function(success, reason)
      if success then
        if on_finish then on_finish(true, reason) end
      elseif attempts < retries then
        vim.notify(string.format("Stream failed, retrying (%d/%d)...", attempts, retries), vim.log.levels.WARN)
        vim.defer_fn(try, delay)
      else
        local error_message = string.format("Stream failed after %d attempts: %s", attempts, reason or "Unknown error")
        vim.notify(error_message, vim.log.levels.ERROR)
        if on_finish then on_finish(false, error_message) end
      end
    end)
  end

  try()
end

-- ---
-- -- Non-Streaming (Aggregated) Request Logic
-- ---

-- Kept for functions that need the full response at once.
function M.ask_llama(prompt, callback)
  local response_chunks = {}

  M.ask_llama_stream(prompt,
    -- on_chunk
    function(chunk)
      table.insert(response_chunks, chunk)
    end,
    -- on_finish
    function(success, reason)
      if success and callback then
        local full_response = table.concat(response_chunks, "")
        callback(full_response, nil)
      elseif not success and callback then
        callback(nil, reason or "Request failed after retries.")
      end
    end
  )
end


-- Model-specific configurations
local model_configs = {
  deepseek = {
    temperature = 0.4,
    repeat_penalty = 1.15,
    repeat_last_n = 256,
    stop = { "<|im_start|>", "<|im_end|>", "user:", "assistant:" },
    num_ctx = 4096,
    max_tokens = 8192
  },
  qwen = {
    temperature = 0.1,
    max_tokens = 8192,
    num_ctx = 32768 -- Qwen has larger context
  },
  default = {
    temperature = 0.1,
    max_tokens = 8192
  }
}

-- Cache for detected model type
local detected_model = nil

-- Detect model type from server
function M.detect_model_type()
  if detected_model then
    return detected_model
  end

  local config = require("flux").config
  -- Try to query the server for model info
  local url = string.format("http://%s:%d/v1/models", config.host, config.port)
  local curl_cmd = string.format("curl -s %s", url)
  local result = vim.fn.system(curl_cmd)

  if vim.v.shell_error == 0 and result then
    local ok, json = pcall(vim.json.decode, result)
    if ok and json and json.data and #json.data > 0 then
      local model_name = json.data[1].id or ""
      model_name = model_name:lower()

      if model_name:match("deepseek") then
        detected_model = "deepseek"
      elseif model_name:match("qwen") then
        detected_model = "qwen"
      else
        detected_model = "default"
      end
    else
      detected_model = "default"
    end
  else
    detected_model = "default"
  end

  -- vim.notify("Detected model type: " .. detected_model, vim.log.levels.INFO) -- Comment out to reduce noise
  return detected_model
end

-- Get model-specific configuration
function M.get_model_config()
  local model_type = M.detect_model_type()
  return model_configs[model_type] or model_configs.default
end

-- Reset model detection (useful when switching models)
function M.reset_model_detection()
  detected_model = nil
  vim.notify("Model detection reset. Will re-detect on next request.", vim.log.levels.INFO)
end

-- Fix code in current buffer
function M.fix_code()
  local handle = progress.start_fix("Analyzing and fixing code...")
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local code = table.concat(lines, "\n")
  local filename = vim.fn.expand("%:t")

  local prompt = string.format([[
Fix any bugs or issues in this %s code:

```%s
%s
```

Respond with only the corrected code, no explanations.
]], filename, vim.bo.filetype, code)

  progress.update(handle, "Sending code to AI...")

  M.ask_llama(prompt, function(response, err)
    if err or not response or response == "" then
      progress.error(handle, "No response from AI")
      vim.notify("No response from LLM: " .. (err or "Empty response"), vim.log.levels.ERROR)
      return
    end

    progress.update(handle, "Processing AI response...")

    -- Try to extract code from response (handle different formats)
    local fixed_code = response

    -- Try to extract from code blocks first
    local code_block = response:match("```[%w]*\n(.-)```")
    if code_block then
      fixed_code = code_block
    else
      -- If no code block, use the whole response but clean it up
      fixed_code = response:gsub("^%s*", ""):gsub("%s*$", "") -- trim whitespace
    end

    -- Replace buffer content
    local new_lines = vim.split(fixed_code, "\n")
    vim.api.nvim_buf_set_lines(0, 0, -1, false, new_lines)

    progress.complete(handle, "Code fixed successfully")
    vim.notify("Code fixed and applied to buffer!", vim.log.levels.INFO)
  end)
end

-- Explain selected code
function M.explain_selection()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local lines = vim.api.nvim_buf_get_lines(0, start_pos[2] - 1, end_pos[2], false)
  local code = table.concat(lines, "\n")

  local prompt = "Explain this code concisely:\n\n" .. code

  M.ask_llama(prompt, function(response)
    if response then
      vim.notify(response, vim.log.levels.INFO)
    end
  end)
end

-- Function to ask embedding model for embeddings
function M.ask_embedding(text, callback)
  local config = require("flux").config
  local payload = {
    model = config.embedding.model or "text-embedding", -- Make model name configurable
    input = text,
  }

  local temp_file = vim.fn.tempname()
  local file = io.open(temp_file, "w")
  if not file then
    if callback then callback(nil, "Failed to create temp file") end
    return
  end

  file:write(vim.json.encode(payload))
  file:close()

  local url = string.format("http://%s:%d/v1/embeddings", config.embedding.host, config.embedding.port)
  local curl_cmd = string.format('timeout 30 curl -s %s -H "Content-Type: application/json" -d @%s', url, temp_file)
  local output_buffer = {}

  vim.fn.jobstart(curl_cmd, {
    on_stdout = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            table.insert(output_buffer, line)
          end
        end
      end
    end,
    on_stderr = function(_, data)
      if data and #data > 0 and data[1] ~= "" then
        vim.notify("LLM Embedding stderr: " .. table.concat(data, "\n"), vim.log.levels.WARN)
      end
    end,
    on_exit = function(_, exit_code)
      vim.fn.delete(temp_file) -- Clean up temp file
      if exit_code == 0 and #output_buffer > 0 then
        local response = table.concat(output_buffer, "")
        local ok, json = pcall(vim.json.decode, response)
        if ok and json and json.data and #json.data > 0 and json.data[1].embedding then
          local embedding = json.data[1].embedding
          vim.notify(string.format("Embedding generated successfully: %d dimensions", #embedding), vim.log.levels.DEBUG)
          if callback then callback(embedding, nil) end
        else
          local error_msg = "Invalid embedding response format"
          if response and response:len() > 0 then
            error_msg = error_msg .. ": " .. response:sub(1, 200)
          end
          vim.notify("Embedding error: " .. error_msg, vim.log.levels.ERROR)
          if callback then callback(nil, error_msg) end
        end
      else
        local error_msg = "Embedding request failed (code: " .. exit_code .. ")"
        if exit_code == 124 then
          error_msg = "Embedding request timed out"
        elseif exit_code == 7 then
          error_msg = "Embedding connection failed - server not responding"
        end
        vim.notify("Embedding error: " .. error_msg, vim.log.levels.ERROR)
        if callback then callback(nil, error_msg) end
      end
    end,
  })
end

return M
