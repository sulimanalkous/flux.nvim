-- Code completion for Flux.nvim
local M = {}

local api = vim.api
local progress = require("ui.progress")

-- Completion state
M.state = {
  enabled = true,
  completion_ns = api.nvim_create_namespace("flux_completion"),
  current_completion = nil,
  timer = nil,
  debounce_delay = 2000, -- 2 seconds - longer delay to reduce requests
  is_completing = false,
  last_completion_pos = nil,
}

-- Get context around cursor for completion
function M.get_completion_context()
  local bufnr = api.nvim_get_current_buf()
  local cursor = api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1
  local col = cursor[2]
  
  -- Get lines around cursor (more context = better completions)
  local start_line = math.max(0, row - 10)
  local end_line = math.min(api.nvim_buf_line_count(bufnr) - 1, row + 5)
  
  local lines = api.nvim_buf_get_lines(bufnr, start_line, end_line + 1, false)
  local filetype = vim.bo[bufnr].filetype
  local filename = vim.fn.expand("%:t")
  
  return {
    lines = lines,
    cursor_line = row - start_line,
    cursor_col = col,
    filetype = filetype,
    filename = filename,
    bufnr = bufnr,
  }
end

-- Async LLM request function
function M.ask_llm_async(prompt, callback)
  local config = require("flux").config
  -- Create JSON payload
  local payload = {
    messages = {
      { role = "user", content = prompt }
    },
    temperature = 0.1,
    max_tokens = 1024, -- Smaller for faster completions
  }
  
  -- Write to temp file
  local temp_file = vim.fn.tempname()
  local file = io.open(temp_file, "w")
  if not file then
    callback(nil, "Failed to create temp file")
    return
  end
  
  file:write(vim.json.encode(payload))
  file:close()
  
  -- Use async job
  local url = string.format("http://%s:%d/v1/chat/completions", config.host, config.port)
  local curl_cmd = string.format('curl -s %s -H "Content-Type: application/json" -d @%s', url, temp_file)
  
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
    on_exit = function(_, exit_code)
      if exit_code == 0 and #output_buffer > 0 then
        local response = table.concat(output_buffer, "")
        local ok, json = pcall(vim.json.decode, response)
        if ok and json.choices and #json.choices > 0 then
          local content = json.choices[1].message.content
          callback(content)
        else
          callback(nil, "Failed to parse JSON")
        end
      else
        callback(nil, "Request failed")
      end
    end,
  })
end

-- Generate completion suggestion
function M.get_completion_suggestion(context)
  -- Only complete at line endings or after specific triggers
  local current_line = context.lines[context.cursor_line + 1] or ""
  local char_before_cursor = current_line:sub(context.cursor_col, context.cursor_col)
  
  -- Skip completion for rapid typing or mid-word
  if char_before_cursor:match("%w") then
    return nil -- Don't complete in middle of words
  end
  
  -- Build prompt for code completion (much shorter)
  local code_before_cursor = ""
  for i = math.max(1, context.cursor_line - 3), context.cursor_line + 1 do
    local line = context.lines[i] or ""
    if i == context.cursor_line + 1 then
      code_before_cursor = code_before_cursor .. line:sub(1, context.cursor_col)
    else
      code_before_cursor = code_before_cursor .. line .. "\n"
    end
  end
  
  -- Shorter, more focused prompt
  local prompt = string.format([[Complete this %s code with 1-2 lines:

```%s
%s
```]], context.filetype, context.filetype, code_before_cursor:trim())

  return prompt
end

-- Show completion as virtual text
function M.show_completion(completion_text, bufnr, row, col)
  -- Clear existing completion
  M.clear_completion(bufnr)
  
  if not completion_text or completion_text:trim() == "" then
    return
  end
  
  -- Split completion into lines
  local completion_lines = vim.split(completion_text, "\n")
  if #completion_lines == 0 then return end
  
  -- Show first line as virtual text after cursor
  local first_line = completion_lines[1]
  if first_line and first_line:trim() ~= "" then
    local virt_text = {{first_line, "Comment"}}
    
    M.state.current_completion = {
      bufnr = bufnr,
      row = row,
      col = col,
      text = completion_text,
      extmark_id = api.nvim_buf_set_extmark(bufnr, M.state.completion_ns, row, col, {
        virt_text = virt_text,
        virt_text_pos = "inline",
      })
    }
  end
end

-- Clear current completion
function M.clear_completion(bufnr)
  if M.state.current_completion and M.state.current_completion.bufnr == bufnr then
    pcall(api.nvim_buf_del_extmark, bufnr, M.state.completion_ns, M.state.current_completion.extmark_id)
    M.state.current_completion = nil
  end
end

-- Accept current completion
function M.accept_completion()
  if not M.state.current_completion then
    return false
  end
  
  local completion = M.state.current_completion
  local bufnr = completion.bufnr
  local row = completion.row
  local col = completion.col
  local text = completion.text
  
  -- Insert the completion text
  local lines = vim.split(text, "\n")
  
  if #lines == 1 then
    -- Single line completion
    local current_line = api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
    local new_line = current_line:sub(1, col) .. text .. current_line:sub(col + 1)
    api.nvim_buf_set_lines(bufnr, row, row + 1, false, {new_line})
    
    -- Move cursor to end of completion
    api.nvim_win_set_cursor(0, {row + 1, col + #text})
  else
    -- Multi-line completion
    local current_line = api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
    local before_cursor = current_line:sub(1, col)
    local after_cursor = current_line:sub(col + 1)
    
    -- Prepare new lines
    local new_lines = {}
    for i, line in ipairs(lines) do
      if i == 1 then
        table.insert(new_lines, before_cursor .. line)
      elseif i == #lines then
        table.insert(new_lines, line .. after_cursor)
      else
        table.insert(new_lines, line)
      end
    end
    
    -- Replace lines
    api.nvim_buf_set_lines(bufnr, row, row + 1, false, new_lines)
    
    -- Move cursor to end
    api.nvim_win_set_cursor(0, {row + #new_lines, #new_lines[#new_lines] - #after_cursor})
  end
  
  -- Clear completion
  M.clear_completion(bufnr)
  return true
end

-- Trigger completion with debouncing
function M.trigger_completion()
  if not M.state.enabled or M.state.is_completing then
    return
  end
  
  local cursor = api.nvim_win_get_cursor(0)
  local current_pos = cursor[1] .. "," .. cursor[2]
  
  -- Skip if we just completed at this position
  if M.state.last_completion_pos == current_pos then
    return
  end
  
  -- Cancel existing timer
  if M.state.timer then
    vim.fn.timer_stop(M.state.timer)
  end
  
  -- Set up new timer
  M.state.timer = vim.fn.timer_start(M.state.debounce_delay, function()
    if M.state.is_completing then return end
    
    M.state.is_completing = true
    
    local context = M.get_completion_context()
    local prompt = M.get_completion_suggestion(context)
    
    -- Skip if no valid prompt
    if not prompt then
      M.state.is_completing = false
      return
    end
    
    -- Start progress indicator
    local handle = progress.start_completion("Generating completion...")
    
    M.ask_llm_async(prompt, function(response, error)
      M.state.is_completing = false
      
      if error then
        progress.error(handle, "Completion failed")
        return
      end
      
      if response and response:trim() ~= "" then
        -- Clean up the response
        local completion = response:trim()
        
        -- Remove code blocks and explanations
        completion = completion:gsub("```.-\n", ""):gsub("```", "")
        completion = completion:gsub("Here.*:", "")
        completion = completion:trim()
        
        -- Only show if completion is reasonable length
        if #completion < 200 and not completion:match("^[Tt]he ") then
          local new_cursor = api.nvim_win_get_cursor(0)
          M.show_completion(completion, context.bufnr, new_cursor[1] - 1, new_cursor[2])
          M.state.last_completion_pos = new_cursor[1] .. "," .. new_cursor[2]
          progress.complete(handle, "Completion ready")
        else
          progress.cancel(handle, "Completion filtered")
        end
      else
        progress.cancel(handle, "No completion generated")
      end
    end)
  end)
end

-- Setup autocommands for completion
function M.setup_autocmds()
  local augroup = api.nvim_create_augroup("FluxCompletion", { clear = true })
  
  -- Trigger completion on text changes
  api.nvim_create_autocmd({"TextChangedI"}, {
    group = augroup,
    callback = function()
      local bufnr = api.nvim_get_current_buf()
      
      -- Only complete in certain filetypes
      local ft = vim.bo[bufnr].filetype
      if ft == "" or ft == "TelescopePrompt" or ft == "markdown" then
        return
      end
      
      M.trigger_completion()
    end,
  })
  
  -- Clear completion on cursor move or mode change
  api.nvim_create_autocmd({"CursorMoved", "CursorMovedI", "ModeChanged"}, {
    group = augroup,
    callback = function()
      local bufnr = api.nvim_get_current_buf()
      M.clear_completion(bufnr)
    end,
  })
  
  -- Clear completion when leaving buffer
  api.nvim_create_autocmd({"BufLeave"}, {
    group = augroup,
    callback = function()
      local bufnr = api.nvim_get_current_buf()
      M.clear_completion(bufnr)
    end,
  })
end

-- Setup completion keymaps
function M.setup_keymaps()
  -- No Tab keymap needed - handled by nvim-cmp integration
  
  -- Manual trigger completion
  vim.keymap.set("i", "<C-Space>", function()
    M.trigger_completion()
  end, { desc = "Trigger Flux completion" })
  
  -- Toggle completion
  vim.keymap.set("n", "<leader>tc", function()
    M.state.enabled = not M.state.enabled
    local status = M.state.enabled and "enabled" or "disabled"
    vim.notify("Flux completion " .. status, vim.log.levels.INFO)
    
    -- Clear any existing completion when disabling
    if not M.state.enabled then
      local bufnr = api.nvim_get_current_buf()
      M.clear_completion(bufnr)
    end
  end, { desc = "Toggle Flux completion" })
end

-- Setup function
function M.setup()
  M.setup_autocmds()
  M.setup_keymaps()
  vim.notify("Flux completion enabled - Tab to accept, <leader>tc to toggle", vim.log.levels.INFO)
end

-- Add string trim function if not available
if not string.trim then
  function string.trim(s)
    return s:match("^%s*(.-)%s*$")
  end
end

return M