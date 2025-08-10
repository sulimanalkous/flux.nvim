-- Simple LLM functions using your llama-server
local M = {}

-- Simple synchronous curl to your llama-server
function M.ask_llama(prompt, callback)
  -- Create JSON payload
  local payload = {
    messages = {
      { role = "user", content = prompt }
    },
    temperature = 0.1,
    max_tokens = 8192
  }
  
  -- Write to temp file
  local temp_file = "/tmp/llm_request.json"
  local file = io.open(temp_file, "w")
  if not file then
    vim.notify("Failed to create temp file", vim.log.levels.ERROR)
    return
  end
  
  file:write(vim.json.encode(payload))
  file:close()
  
  -- Use synchronous system call
  local curl_cmd = string.format('curl -s http://localhost:1234/v1/chat/completions -H "Content-Type: application/json" -d @%s', temp_file)
  local response = vim.fn.system(curl_cmd)
  
  if vim.v.shell_error ~= 0 then
    vim.notify("Curl failed with error code: " .. vim.v.shell_error, vim.log.levels.ERROR)
    vim.notify("Response: " .. response, vim.log.levels.ERROR)
    return
  end
  
  local ok, json = pcall(vim.json.decode, response)
  if ok and json.choices and #json.choices > 0 then
    local content = json.choices[1].message.content
    if callback then callback(content) end
  else
    vim.notify("Failed to parse JSON: " .. response, vim.log.levels.ERROR)
  end
end

-- Fix code in current buffer
function M.fix_code()
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

  vim.notify("Fixing code...", vim.log.levels.INFO)
  
  M.ask_llama(prompt, function(response)
    if not response or response == "" then
      vim.notify("No response from LLM", vim.log.levels.ERROR)
      return
    end
    
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
    vim.notify(response, vim.log.levels.INFO)
  end)
end

-- Setup keymaps
function M.setup()
  -- Simple keymaps
  vim.keymap.set("n", "<leader>lf", M.fix_code, { desc = "Fix code with LLM" })
  vim.keymap.set("v", "<leader>le", M.explain_selection, { desc = "Explain selection with LLM" })
  vim.keymap.set("n", "<leader>lp", function()
    local prompt = vim.fn.input("Ask LLM: ")
    if prompt ~= "" then
      M.ask_llama(prompt, function(response)
        vim.notify(response, vim.log.levels.INFO)
      end)
    end
  end, { desc = "Ask LLM prompt" })
  
  -- Setup Flux.nvim (our custom LLM plugin)
  local flux = require("flux")
  flux.setup()
  
  -- Setup edit interface
  local flux_edit = require("flux.edit")
  vim.keymap.set("v", "<leader>ae", flux_edit.edit_selection, { desc = "Edit selection with Flux" })
  vim.keymap.set("n", "<leader>af", flux_edit.edit_buffer, { desc = "Edit buffer with Flux" })
  
  -- Setup completion (like Copilot!)
  local flux_completion = require("flux.completion")
  flux_completion.setup()
end

return M