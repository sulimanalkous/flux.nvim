-- My LLM Plugin - Simplified Avante-inspired interface
local M = {}

local api = vim.api
local fn = vim.fn

-- Simple state tracking
M.state = {
  sidebar = nil,
  chat_buf = nil,
  input_buf = nil,
  result_buf = nil,
}

-- Import our working LLM functions
local simple_llm = require("simple-llm")

-- Create a simple chat interface
function M.create_chat_interface()
  -- Create main window split
  local width = math.floor(vim.o.columns * 0.4)
  local height = vim.o.lines - 4
  
  -- Create chat buffer
  M.state.chat_buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(M.state.chat_buf, "buftype", "nofile")
  api.nvim_buf_set_option(M.state.chat_buf, "filetype", "markdown")
  api.nvim_buf_set_name(M.state.chat_buf, "LLM_CHAT")
  
  -- Create input buffer
  M.state.input_buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(M.state.input_buf, "buftype", "nofile")
  api.nvim_buf_set_name(M.state.input_buf, "LLM_INPUT")
  
  -- Open chat window on the right
  vim.cmd("vsplit")
  local win = api.nvim_get_current_win()
  api.nvim_win_set_buf(win, M.state.chat_buf)
  api.nvim_win_set_width(win, width)
  
  -- Set initial content
  local welcome_lines = {
    "# LLM Chat with File Operations",
    "",
    "🚀 **Enhanced AI Assistant** - I can now:",
    "- 💬 **Chat** about anything",
    "- ✏️ **Edit** your current open file",
    "- 📖 **Read** any file or directory",
    "",
    "**Examples:**",
    "- \"Fix the bugs in this code\"",
    "- \"Read the docs/ directory\"",
    "- \"Show me the README.md file\"",
    "",
    "**Controls:**",
    "- `Ctrl+S` - Send message", 
    "- `q` - Close chat (in chat window)",
    "",
    "---",
    "",
  }
  api.nvim_buf_set_lines(M.state.chat_buf, 0, -1, false, welcome_lines)
  
  -- Create input area at bottom
  vim.cmd("split")
  local input_win = api.nvim_get_current_win()
  api.nvim_win_set_buf(input_win, M.state.input_buf)
  api.nvim_win_set_height(input_win, 5)
  
  -- Set input prompt
  api.nvim_buf_set_lines(M.state.input_buf, 0, -1, false, {"Ask: "})
  
  -- Set up keymaps for this buffer
  M.setup_chat_keymaps()
  
  -- Focus on input
  vim.cmd("startinsert")
  api.nvim_win_set_cursor(input_win, {1, 5}) -- After "Ask: "
end

-- Set up keymaps for chat interface
function M.setup_chat_keymaps()
  local opts = { buffer = M.state.input_buf, silent = true }
  
  -- Send message with Ctrl+S
  vim.keymap.set({"n", "i"}, "<C-s>", function()
    M.send_message()
  end, opts)
  
  -- Close chat
  vim.keymap.set("n", "q", function()
    M.close_chat()
  end, { buffer = M.state.chat_buf, silent = true })
end

-- Get current buffer context for chat
function M.get_current_buffer_context()
  local current_buf = vim.fn.bufnr('#') ~= -1 and vim.fn.bufnr('#') or vim.fn.bufnr('%')
  if current_buf == M.state.chat_buf or current_buf == M.state.input_buf then
    -- Try to find the last code buffer
    for i = 1, vim.fn.bufnr('$') do
      if api.nvim_buf_is_valid(i) and vim.bo[i].buftype == "" then
        current_buf = i
        break
      end
    end
  end
  
  if api.nvim_buf_is_valid(current_buf) and vim.bo[current_buf].buftype == "" then
    local lines = api.nvim_buf_get_lines(current_buf, 0, -1, false)
    local filename = api.nvim_buf_get_name(current_buf)
    local filetype = vim.bo[current_buf].filetype
    
    return {
      filename = filename,
      basename = vim.fn.fnamemodify(filename, ":t"),
      filetype = filetype,
      lines = lines,
      bufnr = current_buf
    }
  end
  return nil
end

-- Send message to LLM with enhanced capabilities
function M.send_message()
  local input_lines = api.nvim_buf_get_lines(M.state.input_buf, 0, -1, false)
  local message = table.concat(input_lines, "\n"):gsub("^Ask: ", ""):trim()

  if message == "" then
    vim.notify("Please enter a message", vim.log.levels.WARN)
    return
  end

  -- Add user message to chat
  M.add_to_chat("**You:** " .. message)
  M.add_to_chat("")
  M.add_to_chat("**LLM:** *thinking...*")

  -- Clear input
  api.nvim_buf_set_lines(M.state.input_buf, 0, -1, false, {"Ask: "})

  -- Enhanced prompt with current context and capabilities
  local enhanced_message = M.build_enhanced_prompt(message)

  -- Send to LLM
  simple_llm.ask_llama(enhanced_message, function(response)
    -- Process response for special commands
    M.process_llm_response(response)
  end)
end

-- Build enhanced prompt with context and capabilities  
function M.build_enhanced_prompt(user_message)
  local context = M.get_current_buffer_context()
  
  local prompt = [[You are a coding assistant with file operation capabilities. You can:

1. **Edit current file**: When asked to edit/fix current code, respond with:
   @EDIT
   ```
   [new code content]
   ```

2. **Read files**: When user asks to read files, respond with:
   @READ path/to/file
   or
   @READ directory/

3. **List directory**: When asked about files in a directory, respond with:
   @LIST directory/

Current context:]]

  if context then
    prompt = prompt .. string.format([[
- **Current file**: %s (%s)
- **File type**: %s
- **Content preview** (first 20 lines):
```%s
%s
```

]], context.basename, context.filename, context.filetype, context.filetype, 
    table.concat(vim.list_slice(context.lines, 1, 20), "\n"))
  else
    prompt = prompt .. "\n- No file currently open\n\n"
  end

  prompt = prompt .. "**User request**: " .. user_message .. "\n\nRespond normally, but use @EDIT, @READ, or @LIST commands when appropriate."

  return prompt
end

-- Process LLM response and handle special commands
function M.process_llm_response(response)
  if not response then
    M.update_chat_response("No response received")
    return
  end

  local processed_response = ""
  local remaining_text = response
  
  -- Process @EDIT commands
  while remaining_text:find("@EDIT") do
    local before_edit, after_edit = remaining_text:match("^(.-)@EDIT(.*)$")
    if before_edit then
      processed_response = processed_response .. before_edit
      
      -- Extract code content (look for code block or take everything until next @command)
      local code_content = ""
      if after_edit:match("^%s*```") then
        -- Extract from code block
        code_content = after_edit:match("^%s*```.-\n(.-)\n```")
        remaining_text = after_edit:gsub("^%s*```.-\n.-\n```", "", 1)
      else
        -- Take everything until next @ command or end
        code_content = after_edit:match("^(.-)\n@") or after_edit
        remaining_text = after_edit:gsub("^.-\n@", "@", 1)
      end
      
      local edit_result = M.handle_edit_command(code_content)
      processed_response = processed_response .. "\n**[✏️ Edited current file]** " .. edit_result .. "\n\n"
    else
      break
    end
  end
  
  -- Process @READ commands  
  while remaining_text:find("@READ") do
    local before_read, path, after_read = remaining_text:match("^(.-)@READ%s+(.-)%s*\n(.*)$")
    if not path then
      before_read, path = remaining_text:match("^(.-)@READ%s+(.-)%s*$")
      after_read = ""
    end
    
    if before_read and path then
      processed_response = processed_response .. before_read
      local read_result = M.handle_read_command(path)
      processed_response = processed_response .. "\n**[📖 Reading " .. path .. "]**\n" .. read_result .. "\n\n"
      remaining_text = after_read or ""
    else
      break
    end
  end
  
  -- Process @LIST commands
  while remaining_text:find("@LIST") do
    local before_list, path, after_list = remaining_text:match("^(.-)@LIST%s+(.-)%s*\n(.*)$")
    if not path then
      before_list, path = remaining_text:match("^(.-)@LIST%s+(.-)%s*$")
      after_list = ""
    end
    
    if before_list and path then
      processed_response = processed_response .. before_list
      local list_result = M.handle_list_command(path)
      processed_response = processed_response .. "\n**[📁 Listing " .. path .. "]**\n" .. list_result .. "\n\n"
      remaining_text = after_list or ""
    else
      break
    end
  end
  
  -- Add any remaining text
  processed_response = processed_response .. remaining_text

  M.update_chat_response(processed_response:trim())
end

-- Update chat with final response
function M.update_chat_response(response)
  local lines = api.nvim_buf_get_lines(M.state.chat_buf, 0, -1, false)
  table.remove(lines) -- Remove "thinking..." line

  -- Split response into individual lines to avoid newline issues
  local response_lines = vim.split(response, "\n")
  
  -- Add LLM prefix to first line
  if #response_lines > 0 then
    table.insert(lines, "**LLM:** " .. response_lines[1])
    -- Add remaining lines
    for i = 2, #response_lines do
      table.insert(lines, response_lines[i])
    end
  else
    table.insert(lines, "**LLM:** " .. response)
  end
  
  table.insert(lines, "")
  table.insert(lines, "---")
  table.insert(lines, "")

  api.nvim_buf_set_lines(M.state.chat_buf, 0, -1, false, lines)

  -- Scroll to bottom
  local chat_win = fn.bufwinnr(M.state.chat_buf)
  if chat_win ~= -1 and api.nvim_win_is_valid(chat_win) then
    pcall(api.nvim_win_set_cursor, chat_win, {#lines, 0})
  end
end

-- Handle @READ command
function M.handle_read_command(path)
  local full_path = vim.fn.expand(path:trim())
  
  if vim.fn.isdirectory(full_path) == 1 then
    local files = vim.fn.glob(full_path .. "/*", false, true)
    if #files == 0 then
      return "Directory is empty or doesn't exist: " .. path
    end
    
    local result = "📁 Files in **" .. path .. "**:\n"
    for _, file in ipairs(files) do
      local basename = vim.fn.fnamemodify(file, ":t")
      local is_dir = vim.fn.isdirectory(file) == 1
      result = result .. (is_dir and "📁 " or "📄 ") .. basename .. "\n"
    end
    return result
  end
  
  if vim.fn.filereadable(full_path) == 1 then
    local lines = vim.fn.readfile(full_path)
    local content = table.concat(lines, "\n")
    if #content > 2000 then
      content = content:sub(1, 2000) .. "\n... (file truncated - " .. #lines .. " total lines)"
    end
    return "```\n" .. content .. "\n```"
  else
    return "❌ File not found or not readable: " .. path
  end
end

-- Handle @EDIT command
function M.handle_edit_command(new_content)
  local context = M.get_current_buffer_context()
  if not context then
    return "❌ No file open to edit"
  end
  
  new_content = new_content:trim()
  if new_content == "" then
    return "❌ No content provided for editing"
  end
  
  local new_lines = vim.split(new_content, "\n")
  api.nvim_buf_set_lines(context.bufnr, 0, -1, false, new_lines)
  
  return "✅ Successfully edited **" .. context.basename .. "** (" .. #new_lines .. " lines)"
end

-- Handle @LIST command  
function M.handle_list_command(path)
  return M.handle_read_command(path)
end

-- Add text to chat buffer
function M.add_to_chat(text)
  local lines = api.nvim_buf_get_lines(M.state.chat_buf, 0, -1, false)
  table.insert(lines, text)
  api.nvim_buf_set_lines(M.state.chat_buf, 0, -1, false, lines)
end

-- Close chat interface
function M.close_chat()
  if M.state.chat_buf then
    pcall(api.nvim_buf_delete, M.state.chat_buf, { force = true })
  end
  if M.state.input_buf then
    pcall(api.nvim_buf_delete, M.state.input_buf, { force = true })
  end
  M.state = { sidebar = nil, chat_buf = nil, input_buf = nil, result_buf = nil }
end

-- Main toggle function
function M.toggle()
  if M.state.chat_buf and api.nvim_buf_is_valid(M.state.chat_buf) then
    M.close_chat()
  else
    M.create_chat_interface()
  end
end

-- Setup function
function M.setup()
  -- Global keymaps
  vim.keymap.set("n", "<leader>ac", M.toggle, { desc = "Toggle LLM Chat" })
  vim.keymap.set("n", "<leader>aa", M.create_chat_interface, { desc = "Open LLM Chat" })
end

-- Add string trim function if not available
if not string.trim then
  function string.trim(s)
    return s:match("^%s*(.-)%s*$")
  end
end

return M