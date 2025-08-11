local M = {}
local api = vim.api

-- Chat state (shared across modules)
local state = require("chat.state")

function M.setup()
  -- Will be implemented during migration
end

-- Create the chat interface
function M.create_interface()
  -- If chat is already open, just focus on it
  if state.state.chat_buf and api.nvim_buf_is_valid(state.state.chat_buf) then
    local chat_win = vim.fn.bufwinnr(state.state.chat_buf)
    if chat_win > 0 and api.nvim_win_is_valid(chat_win) then
      api.nvim_set_current_win(chat_win)
      return
    end
  end

    -- Create sidebar container on the right side
  local sidebar_width = math.floor(vim.o.columns * 0.4) -- 40% of screen width
  
  -- Create container buffer (this will hold all our windows)
  state.state.container_buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(state.state.container_buf, "buftype", "nofile")
  api.nvim_buf_set_option(state.state.container_buf, "filetype", "FluxSidebar")
  pcall(api.nvim_buf_set_name, state.state.container_buf, "FLUX_SIDEBAR_" .. os.time())
  
  -- Create result buffer (for AI responses)
  state.state.chat_buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(state.state.chat_buf, "buftype", "nofile")
  api.nvim_buf_set_option(state.state.chat_buf, "filetype", "markdown")
  pcall(api.nvim_buf_set_name, state.state.chat_buf, "LLM_RESULT_" .. os.time())
  
  -- Create input buffer (for user input)
  state.state.input_buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(state.state.input_buf, "buftype", "nofile")
  api.nvim_buf_set_option(state.state.input_buf, "filetype", "markdown")
  pcall(api.nvim_buf_set_name, state.state.input_buf, "LLM_INPUT_" .. os.time())
  
  -- Create status buffer (for status bar)
  state.state.status_buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(state.state.status_buf, "buftype", "nofile")
  api.nvim_buf_set_option(state.state.status_buf, "filetype", "FluxStatus")
  pcall(api.nvim_buf_set_name, state.state.status_buf, "FLUX_STATUS_" .. os.time())
  
  -- Create vertical split for sidebar container
  vim.cmd("vsplit")
  local container_win = api.nvim_get_current_win()
  api.nvim_win_set_buf(container_win, state.state.container_buf)
  api.nvim_win_set_width(container_win, sidebar_width)
  
  -- Store container window ID for management
  state.state.container_win = container_win
  
  -- Now create the internal windows within the container
  -- First, create horizontal split inside container for result and input
  vim.cmd("split")
  
  -- Set up result window (top, auto height)
  local result_win = api.nvim_get_current_win()
  api.nvim_win_set_buf(result_win, state.state.chat_buf)
  
  -- Set text wrapping options for result window
  api.nvim_win_set_option(result_win, "wrap", true)
  api.nvim_win_set_option(result_win, "linebreak", true)
  api.nvim_win_set_option(result_win, "breakindent", true)
  api.nvim_win_set_option(result_win, "showbreak", "↳ ")
  
  -- Disable completion for result buffer to prevent interference
  api.nvim_buf_set_option(state.state.chat_buf, "complete", "")
  api.nvim_buf_set_option(state.state.chat_buf, "completeopt", "")
  
  -- Set up input window (bottom 20%)
  vim.cmd("wincmd j") -- Move to bottom window
  local input_win = api.nvim_get_current_win()
  api.nvim_win_set_buf(input_win, state.state.input_buf)
  
  -- Set options for input window
  api.nvim_win_set_option(input_win, "wrap", true)
  api.nvim_win_set_option(input_win, "linebreak", true)
  
  -- Disable completion for input buffer
  api.nvim_buf_set_option(state.state.input_buf, "complete", "")
  api.nvim_buf_set_option(state.state.input_buf, "completeopt", "")
  
  -- Create status window (bottom 5%)
  vim.cmd("split")
  local status_win = api.nvim_get_current_win()
  api.nvim_win_set_buf(status_win, state.state.status_buf)
  
  -- Set options for status window
  api.nvim_win_set_option(status_win, "wrap", false)
  api.nvim_win_set_option(status_win, "linebreak", false)
  
  -- Store window IDs for management
  state.state.result_win = result_win
  state.state.input_win = input_win
  state.state.status_win = status_win
  
  -- Now set the window heights properly using vim.cmd for better compatibility
  -- Switch to input window and resize it
  api.nvim_set_current_win(input_win)
  local input_height = 2  -- Fixed small height for input
  vim.cmd("resize " .. input_height)
  
  -- Switch to status window and resize it
  api.nvim_set_current_win(status_win)
  local status_height = 1  -- Fixed small height for status
  vim.cmd("resize " .. status_height)
  
  -- Switch back to input window for focus
  api.nvim_set_current_win(input_win)
  
  -- Debug: Print the heights we're setting
  vim.notify("Flux.nvim: Set input height to " .. input_height .. ", status height to " .. status_height, vim.log.levels.DEBUG)
  
  -- Set initial content for result window
  local welcome_lines = {
    "# 🤖 Flux.nvim - Your AI Coding Partner",
    "",
    "👋 **Hello! I'm your intelligent coding assistant and thinking partner.**",
    "",
    "**What I can do:**",
    "🧠 **Think & Reason** - I think step-by-step and explain my reasoning",
    "💬 **Natural Conversation** - Chat with me like a helpful colleague",
    "🔧 **Code Operations** - Edit, create, read files, and debug code",
    "📁 **Project Context** - I understand your entire codebase",
    "🎯 **Problem Solving** - Let's work together to solve complex problems",
    "",
    "**How to interact:**",
    "- Just talk to me naturally! Ask questions, discuss problems, or request help",
    "- \"What do you think about this code?\"",
    "- \"Help me debug this issue\"",
    "- \"Let's plan the architecture for this feature\"",
    "- \"Can you explain how this works?\"",
    "",
    "**Special Commands:**",
    "- `#{buffer}` - Reference current file content",
    "- `/help` - Show detailed help",
    "- `/clear` - Clear conversation history",
    "- `/buffer` - Pin a specific buffer",
    "",
    "**Controls:**",
    "- `Ctrl+S` - Send message", 
    "- `q` - Close chat (in chat window)",
    "",
    "Let's start coding together! 🚀",
    "",
    "---",
    "",
  }
  api.nvim_buf_set_lines(state.state.chat_buf, 0, -1, false, welcome_lines)
  
  -- Set initial content for input window
  local input_lines = {
    "**Ask:** ",
  }
  api.nvim_buf_set_lines(state.state.input_buf, 0, -1, false, input_lines)
  
  -- Set initial content for status window
  local status_lines = {
    "🤖 Flux.nvim - Ready",
  }
  api.nvim_buf_set_lines(state.state.status_buf, 0, -1, false, status_lines)
  
  -- Set up keymaps for all buffers
  M.setup_keymaps()
  
  -- Focus on input window and position cursor
  api.nvim_set_current_win(state.state.input_win)
  vim.cmd("startinsert")
  -- Set cursor to the input line, after "**Ask:** "
  local input_lines = api.nvim_buf_get_lines(state.state.input_buf, 0, -1, false)
  if #input_lines > 0 then
    local last_line_content = input_lines[1]
    local cursor_col = math.min(7, #last_line_content)
    pcall(api.nvim_win_set_cursor, state.state.input_win, {1, cursor_col})
  end
end

-- Set up keymaps for chat interface
function M.setup_keymaps()
  -- Clear existing keymaps first to prevent duplicates
  pcall(vim.keymap.del, {"n", "i"}, "<C-s>", { buffer = state.state.input_buf })
  pcall(vim.keymap.del, "n", "q", { buffer = state.state.chat_buf })
  pcall(vim.keymap.del, "n", "q", { buffer = state.state.container_buf })
  
  -- Check if keymap already exists to prevent duplicates
  local has_keymap = false
  pcall(function()
    local existing = vim.fn.maparg("<C-s>", "i", false, true)
    if existing and existing.buffer == state.state.input_buf then
      has_keymap = true
    end
  end)
  
  if has_keymap then
    vim.notify("Flux.nvim: Keymap already exists, skipping setup", vim.log.levels.DEBUG)
    return
  end
  
  -- Send message with Ctrl+S in input buffer
  vim.keymap.set("i", "<C-s>", function()
    require("chat.input").send_message()
  end, { buffer = state.state.input_buf, silent = true })
  
  -- Close entire sidebar from any buffer in the container
  vim.keymap.set("n", "q", function()
    M.close()
  end, { buffer = state.state.chat_buf, silent = true })
  
  vim.keymap.set("n", "q", function()
    M.close()
  end, { buffer = state.state.input_buf, silent = true })
  
  vim.keymap.set("n", "q", function()
    M.close()
  end, { buffer = state.state.status_buf, silent = true })
  
  vim.keymap.set("n", "q", function()
    M.close()
  end, { buffer = state.state.container_buf, silent = true })
end

-- Close chat interface (entire sidebar container)
function M.close()
  if state.state.container_win and api.nvim_win_is_valid(state.state.container_win) then
    -- Close the entire container window
    api.nvim_win_close(state.state.container_win, true)
  end
  
  -- Clean up buffers
  if state.state.chat_buf then
    pcall(api.nvim_buf_delete, state.state.chat_buf, { force = true })
  end
  if state.state.input_buf then
    pcall(api.nvim_buf_delete, state.state.input_buf, { force = true })
  end
  if state.state.status_buf then
    pcall(api.nvim_buf_delete, state.state.status_buf, { force = true })
  end
  if state.state.container_buf then
    pcall(api.nvim_buf_delete, state.state.container_buf, { force = true })
  end
  
  -- Reset state
  state.state.chat_buf = nil
  state.state.input_buf = nil
  state.state.status_buf = nil
  state.state.container_buf = nil
  state.state.container_win = nil
  state.state.result_win = nil
  state.state.input_win = nil
  state.state.status_win = nil
end

-- Toggle chat interface
function M.toggle()
  if state.state.container_win and api.nvim_win_is_valid(state.state.container_win) then
    M.close()
  else
    M.create_interface()
  end
end

-- Add text to chat buffer
function M.add_to_chat(text)
  if not state.state.chat_buf or not api.nvim_buf_is_valid(state.state.chat_buf) then
    return
  end
  
  local lines = vim.split(text, "\n", { plain = true })
  local current_lines = api.nvim_buf_get_lines(state.state.chat_buf, 0, -1, false)
  
  -- Append new lines
  for _, line in ipairs(lines) do
    table.insert(current_lines, line)
  end
  
  -- Update buffer
  api.nvim_buf_set_lines(state.state.chat_buf, 0, -1, false, current_lines)
  
  -- Scroll to bottom
  M.scroll_to_bottom()
end

-- Scroll chat window to bottom
function M.scroll_to_bottom()
  if state.state.result_win and api.nvim_win_is_valid(state.state.result_win) then
    local lines = api.nvim_buf_get_lines(state.state.chat_buf, 0, -1, false)
    local line_count = #lines
    if line_count > 0 then
      -- Position cursor at the end of the last line
      local last_line_content = lines[line_count]
      local cursor_col = math.max(0, #last_line_content)
      pcall(api.nvim_win_set_cursor, state.state.result_win, {line_count, cursor_col})
    end
  end
end

return M
