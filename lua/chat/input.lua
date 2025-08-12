local M = {}
local api = vim.api

-- Chat state (shared across modules)
local state = require("chat.state")

function M.setup()
  -- Will be implemented during migration
end

-- Send message to LLM
function M.send_message()
  -- Prevent multiple simultaneous sends with more robust checking
  if state.state.is_streaming then
    vim.notify("Already processing a message, please wait...", vim.log.levels.WARN)
    return
  end
  
  -- Additional protection: check if we're already processing this exact message
  if state.state.processing_message then
    vim.notify("Message already being processed, please wait...", vim.log.levels.WARN)
    return
  end

  -- Get the input line from the input buffer
  local input_lines = api.nvim_buf_get_lines(state.state.input_buf, 0, -1, false)
  local input_line = input_lines[1] or ""
  local message = vim.trim(input_line:gsub("^%*%*Ask:%*%* ", ""))

  if message == "" then
    vim.notify("Please enter a message", vim.log.levels.WARN)
    return
  end

  -- Generate unique message ID to prevent duplicate processing
  local message_id = os.time() .. "_" .. math.random(1000, 9999)
  state.state.current_message_id = message_id
  
  -- Set streaming state to prevent multiple sends
  state.state.is_streaming = true
  state.state.processing_message = true

  -- Debug: Log the message being sent
  vim.notify("Flux.nvim: Sending message: " .. message:sub(1, 50) .. " (ID: " .. message_id .. ")", vim.log.levels.DEBUG)

  -- Clear input buffer and add user message to result buffer
  api.nvim_buf_set_lines(state.state.input_buf, 0, -1, false, {"**Ask:** "})
  require("chat.ui").add_to_chat("**You:** " .. message)
  require("chat.ui").add_to_chat("")

  -- Check for help command
  if message:lower():match("^/?help$") or message:lower():match("^/?commands$") then
    require("chat.commands").show_help()
    M.add_input_prompt()
    return
  end

  -- Check for /buffer command
  if message:lower():match("^/?buffer$") then
    require("chat.commands").show_buffer_picker()
    M.add_input_prompt()
    return
  end

  -- Check for /clear command
  if message:lower():match("^/?clear$") then
    require("chat.commands").clear_history()
    require("chat.ui").add_to_chat("**System:** Conversation history cleared. Fresh start!")
    require("chat.ui").add_to_chat("")
    require("chat.ui").add_to_chat("---")
    require("chat.ui").add_to_chat("")
    M.add_input_prompt()
    return
  end

  -- Check for #{buffer} reference
  if message:match("#{buffer}") then
    require("chat.messages").handle_buffer_reference(message)
    return
  end

  -- Check for complex reasoning tasks
  local lower_msg = message:lower()
  if lower_msg:match("think") or
     lower_msg:match("reason") or
     lower_msg:match("plan") or
     lower_msg:match("design") or
     lower_msg:match("architecture") or
     lower_msg:match("debug") or
     lower_msg:match("problem") or
     lower_msg:match("help me") or
     lower_msg:match("how should") or
     lower_msg:match("what do you think") or
     lower_msg:match("let's work") or
     lower_msg:match("step by step") then
    require("chat.messages").handle_complex_reasoning(message)
    return
  end

  -- Check for file operations (more comprehensive patterns)
  if lower_msg:match("read.*%.%w+") or -- read any file with extension
     lower_msg:match("read.*file") or    -- read ... file
     lower_msg:match("show.*%.%w+") or   -- show any file with extension
     lower_msg:match("read.*and.*update") or -- read X and update Y
     lower_msg:match("read.*update") then   -- read ... update
    require("chat.messages").handle_complex_file_request(message)
    return
  end

  -- Regular message processing
  require("chat.messages").process_regular_message(message)
end

-- Add input prompt to the input buffer
function M.add_input_prompt()
  -- Clear input buffer and add prompt
  api.nvim_buf_set_lines(state.state.input_buf, 0, -1, false, {"**Ask:** "})
  
  -- Switch to input window and position cursor
  if state.state.input_win and api.nvim_win_is_valid(state.state.input_win) then
    api.nvim_set_current_win(state.state.input_win)
    pcall(api.nvim_win_set_cursor, state.state.input_win, {1, 7}) -- After "**Ask:** "
    vim.cmd("startinsert")
  end
end

return M
