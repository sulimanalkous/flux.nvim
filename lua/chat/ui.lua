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

  -- Create split layout: result window (80%) on top, input window (20%) on bottom
  local total_height = vim.o.lines - 4 -- Account for status line and command line
  local result_height = math.floor(total_height * 0.8)
  local input_height = math.floor(total_height * 0.2)
  
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
  
  -- Create horizontal split
  vim.cmd("split")
  
  -- Set up result window (top 80%)
  local result_win = api.nvim_get_current_win()
  api.nvim_win_set_buf(result_win, state.state.chat_buf)
  api.nvim_win_set_height(result_win, result_height)
  
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
  api.nvim_win_set_height(input_win, input_height)
  
  -- Set options for input window
  api.nvim_win_set_option(input_win, "wrap", true)
  api.nvim_win_set_option(input_win, "linebreak", true)
  
  -- Disable completion for input buffer
  api.nvim_buf_set_option(state.state.input_buf, "complete", "")
  api.nvim_buf_set_option(state.state.input_buf, "completeopt", "")
  
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
  
  -- Set up keymaps for both buffers
  M.setup_keymaps()
  
  -- Focus on input window and position cursor
  vim.cmd("wincmd j") -- Move to input window
  vim.cmd("startinsert")
  -- Set cursor to the input line, after "**Ask:** "
  local input_lines = api.nvim_buf_get_lines(state.state.input_buf, 0, -1, false)
  if #input_lines > 0 then
    local last_line_content = input_lines[1]
    local cursor_col = math.min(7, #last_line_content)
    pcall(api.nvim_win_set_cursor, api.nvim_get_current_win(), {1, cursor_col})
  end
end

-- Set up keymaps for chat interface
function M.setup_keymaps()
  -- Clear existing keymaps first to prevent duplicates
  pcall(vim.keymap.del, {"n", "i"}, "<C-s>", { buffer = state.state.input_buf })
  pcall(vim.keymap.del, "n", "q", { buffer = state.state.chat_buf })
  
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
  
  -- Close chat from result buffer
  vim.keymap.set("n", "q", function()
    M.close()
  end, { buffer = state.state.chat_buf, silent = true })
end

-- Close chat interface
function M.close()
  if state.state.chat_buf then
    pcall(api.nvim_buf_delete, state.state.chat_buf, { force = true })
  end
  if state.state.input_buf then
    pcall(api.nvim_buf_delete, state.state.input_buf, { force = true })
  end
  -- Keep conversation history when closing chat (persist in session)
  state.state.chat_buf = nil
  state.state.input_buf = nil
end

-- Toggle chat interface
function M.toggle()
  if state.state.chat_buf and api.nvim_buf_is_valid(state.state.chat_buf) then
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
  local chat_win = vim.fn.bufwinnr(state.state.chat_buf)
  if chat_win ~= -1 and api.nvim_win_is_valid(chat_win) then
    local lines = api.nvim_buf_get_lines(state.state.chat_buf, 0, -1, false)
    local line_count = #lines
    if line_count > 0 then
      -- Position cursor at the end of the last line
      local last_line_content = lines[line_count]
      local cursor_col = math.max(0, #last_line_content)
      pcall(api.nvim_win_set_cursor, chat_win, {line_count, cursor_col})
    end
  end
end

return M
