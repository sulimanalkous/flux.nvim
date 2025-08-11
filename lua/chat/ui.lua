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

  -- Create main window split
  local width = math.floor(vim.o.columns * 0.4)
  
  -- Create single chat buffer for both chat and input
  state.state.chat_buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(state.state.chat_buf, "buftype", "nofile")
  api.nvim_buf_set_option(state.state.chat_buf, "filetype", "markdown")
  pcall(api.nvim_buf_set_name, state.state.chat_buf, "LLM_CHAT_" .. os.time())
  
  -- Use the same buffer for input (no separate input buffer)
  state.state.input_buf = state.state.chat_buf
  
  -- Open chat window on the right
  vim.cmd("vsplit")
  local win = api.nvim_get_current_win()
  api.nvim_win_set_buf(win, state.state.chat_buf)
  api.nvim_win_set_width(win, width)
  
  -- Set text wrapping options for chat window
  api.nvim_win_set_option(win, "wrap", true)
  api.nvim_win_set_option(win, "linebreak", true)
  api.nvim_win_set_option(win, "breakindent", true)
  api.nvim_win_set_option(win, "showbreak", "↳ ")
  
  -- Set initial content
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
    "**Ask:** ",
  }
  api.nvim_buf_set_lines(state.state.chat_buf, 0, -1, false, welcome_lines)
  
  -- Set up keymaps for this buffer
  M.setup_keymaps()
  
  -- Focus on input area at the bottom
  vim.cmd("startinsert")
  api.nvim_win_set_cursor(win, {#welcome_lines, 7}) -- After "**Ask:** "
end

-- Set up keymaps for chat interface
function M.setup_keymaps()
  local opts = { buffer = state.state.input_buf, silent = true }
  
  -- Send message with Ctrl+S
  vim.keymap.set({"n", "i"}, "<C-s>", function()
    require("chat.input").send_message()
  end, opts)
  
  -- Close chat
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
    pcall(api.nvim_win_set_cursor, chat_win, {#lines, 0})
  end
end

return M
