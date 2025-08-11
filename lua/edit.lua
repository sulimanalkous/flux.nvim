-- Edit mode for My LLM Plugin
local M = {}

local api = vim.api
local simple_llm = require("simple-llm")
local progress = require("ui.progress")
local diff_ui = require("ui.diff")

-- Edit selected code with LLM
function M.edit_selection()
  -- Get selected text
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  
  if start_pos[2] == 0 or end_pos[2] == 0 then
    vim.notify("Please select some text first", vim.log.levels.WARN)
    return
  end
  
  local lines = api.nvim_buf_get_lines(0, start_pos[2] - 1, end_pos[2], false)
  local selected_code = table.concat(lines, "\n")
  local filetype = vim.bo.filetype
  
  -- Create edit interface
  M.create_edit_interface(selected_code, filetype, start_pos[2] - 1, end_pos[2])
end

-- Edit entire buffer
function M.edit_buffer()
  local lines = api.nvim_buf_get_lines(0, 0, -1, false)
  local code = table.concat(lines, "\n")
  local filetype = vim.bo.filetype
  
  M.create_edit_interface(code, filetype, 0, -1)
end

-- Create the edit interface
function M.create_edit_interface(code, filetype, start_line, end_line)
  local original_buf = api.nvim_get_current_buf()
  
  -- Create split window for editing
  vim.cmd("vsplit")
  local edit_buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(edit_buf, "buftype", "nofile")
  api.nvim_buf_set_option(edit_buf, "filetype", "markdown")
  api.nvim_buf_set_name(edit_buf, "LLM_EDIT")
  
  local edit_win = api.nvim_get_current_win()
  api.nvim_win_set_buf(edit_win, edit_buf)
  
  -- Set up the edit interface
  local interface_lines = {
    "# LLM Code Editor",
    "",
    "**Instructions:** Describe what you want to do with the code below:",
    "",
    "```instruction",
    "Fix bugs and improve the code",
    "```",
    "",
    "**Original Code:**",
    "```" .. filetype,
    code,
    "```",
    "",
    "---",
    "",
    "Press <leader>e to edit | q to close | <leader>a to apply changes",
  }
  
  api.nvim_buf_set_lines(edit_buf, 0, -1, false, interface_lines)
  
  -- Set up keymaps
  local opts = { buffer = edit_buf, silent = true }
  
  vim.keymap.set("n", "<leader>e", function()
    M.process_edit(edit_buf, original_buf, start_line, end_line, filetype)
  end, opts)
  
  vim.keymap.set("n", "q", function()
    api.nvim_buf_delete(edit_buf, { force = true })
  end, opts)
  
  -- Position cursor at instruction area
  api.nvim_win_set_cursor(edit_win, {6, 0})
  vim.cmd("startinsert")
end

-- Process the edit request
function M.process_edit(edit_buf, original_buf, start_line, end_line, filetype)
  -- Get the instruction and original code
  local lines = api.nvim_buf_get_lines(edit_buf, 0, -1, false)
  
  -- Extract instruction (between ```instruction and ```)
  local instruction = ""
  local in_instruction = false
  local original_code = ""
  local in_code = false
  
  for _, line in ipairs(lines) do
    if line == "```instruction" then
      in_instruction = true
    elseif line:match("^```$") and in_instruction then
      in_instruction = false
    elseif in_instruction then
      instruction = instruction .. line .. "\n"
    elseif line == "```" .. filetype then
      in_code = true
    elseif line:match("^```$") and in_code then
      in_code = false
    elseif in_code then
      original_code = original_code .. line .. "\n"
    end
  end
  
  instruction = instruction:trim()
  if instruction == "" then
    vim.notify("Please provide instructions for editing", vim.log.levels.WARN)
    return
  end
  
  -- Create prompt for LLM
  local prompt = string.format([[
%s

Original %s code:
```%s
%s
```

Respond with only the modified code, no explanations.
]], instruction, filetype, filetype, original_code:trim())

  -- Show processing message
  M.add_result_to_edit(edit_buf, "**Processing...** " .. instruction)
  
  -- Start progress indicator
  local handle = progress.start_edit("Processing edit request...")
  
  -- Send to LLM
  simple_llm.ask_llama(prompt, function(response)
    if not response then
      progress.error(handle, "No response received")
      vim.notify("No response from LLM", vim.log.levels.ERROR)
      return
    end
    
    progress.update(handle, "Processing AI response...")
    
    -- Extract code from response
    local new_code = response
    local code_block = response:match("```.-\n(.-)```")
    if code_block then
      new_code = code_block
    end
    
    progress.complete(handle, "Edit response ready")
    
    -- Close the edit buffer
    api.nvim_buf_delete(edit_buf, { force = true })
    
    -- Show diff interface instead of immediately applying
    M.show_edit_diff(original_buf, new_code, start_line, end_line, instruction)
  end)
end

-- Add text to edit buffer
function M.add_result_to_edit(buf, text)
  local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
  table.insert(lines, text)
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  
  -- Scroll to bottom
  local win = vim.fn.bufwinnr(buf)
  if win ~= -1 then
    api.nvim_win_set_cursor(win, {#lines, 0})
  end
end

-- Show diff interface for edit results
function M.show_edit_diff(original_buf, new_code, start_line, end_line, instruction)
  if not original_buf or not api.nvim_buf_is_valid(original_buf) then
    vim.notify("Original buffer is no longer valid", vim.log.levels.ERROR)
    return
  end
  
  local title = "Edit: " .. (instruction or "AI Code Edit")
  
  if start_line == 0 and end_line == -1 then
    -- Full buffer edit
    diff_ui.show_edit_diff(original_buf, new_code, title)
  else
    -- Partial edit - need to reconstruct full content
    local original_lines = api.nvim_buf_get_lines(original_buf, 0, -1, false)
    local new_lines = vim.split(new_code, "\n")
    
    -- Create full modified content
    local modified_lines = {}
    
    -- Add lines before the edit
    for i = 1, start_line do
      table.insert(modified_lines, original_lines[i])
    end
    
    -- Add new lines
    for _, line in ipairs(new_lines) do
      table.insert(modified_lines, line)
    end
    
    -- Add lines after the edit (if end_line is not -1)
    if end_line ~= -1 then
      for i = end_line + 1, #original_lines do
        table.insert(modified_lines, original_lines[i])
      end
    end
    
    diff_ui.show_diff(original_lines, modified_lines, original_buf, title)
  end
end

-- Apply changes to original buffer (legacy function, kept for compatibility)
function M.apply_changes(original_buf, new_code, start_line, end_line, edit_buf)
  local new_lines = vim.split(new_code, "\n")
  
  -- Apply to original buffer
  api.nvim_buf_set_lines(original_buf, start_line, end_line, false, new_lines)
  
  vim.notify("Changes applied!", vim.log.levels.INFO)
  
  -- Close edit buffer if provided
  if edit_buf and api.nvim_buf_is_valid(edit_buf) then
    api.nvim_buf_delete(edit_buf, { force = true })
  end
end

-- Add string trim function if not available
if not string.trim then
  function string.trim(s)
    return s:match("^%s*(.-)%s*$")
  end
end

return M