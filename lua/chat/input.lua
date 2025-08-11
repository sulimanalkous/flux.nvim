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

  -- Get the last line (input line) from the chat buffer
  local all_lines = api.nvim_buf_get_lines(state.state.chat_buf, 0, -1, false)
  local last_line = all_lines[#all_lines] or ""
  local message = last_line:gsub("^%*%*Ask:%*%* ", ""):trim()

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
  vim.notify("Flux.nvim: Sending message: " .. message:sub(1, 50) .. " (ID: " .. message_id .. ", streaming: " .. tostring(state.state.is_streaming) .. ")", vim.log.levels.DEBUG)
  
  -- Check if this is being triggered by Enter key
  local mode = vim.fn.mode()
  vim.notify("Flux.nvim: Current mode: " .. mode, vim.log.levels.DEBUG)
  
  -- Add call stack trace for debugging
  local trace = debug.traceback()
  vim.notify("Flux.nvim: Call stack: " .. trace:sub(1, 200), vim.log.levels.DEBUG)

  -- Remove the input line and add user message
  api.nvim_buf_set_lines(state.state.chat_buf, #all_lines - 1, #all_lines, false, {})
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

-- Add input prompt to the end of the chat buffer
function M.add_input_prompt()
  require("chat.ui").add_to_chat("**Ask:** ")
  -- Move cursor to the input line
  local lines = api.nvim_buf_get_lines(state.state.chat_buf, 0, -1, false)
  api.nvim_win_set_cursor(api.nvim_get_current_win(), {#lines, 7}) -- After "**Ask:** "
  vim.cmd("startinsert")
end

return M
