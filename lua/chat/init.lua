local M = {}

-- Chat state
M.state = {
  chat_buf = nil,
  input_buf = nil,
  pinned_buffer = nil,
  conversation_history = {},
  is_streaming = false
}

-- Load all chat modules
local ui = require("chat.ui")
local input = require("chat.input")
local messages = require("chat.messages")
local commands = require("chat.commands")
local streaming = require("chat.streaming")
local markdown = require("chat.markdown")

-- Expose modules
M.ui = ui
M.input = input
M.messages = messages
M.commands = commands
M.streaming = streaming
M.markdown = markdown

-- Initialize chat system
function M.setup()
  -- Initialize all modules
  ui.setup()
  input.setup()
  messages.setup()
  commands.setup()
  streaming.setup()
  markdown.setup()
end

-- Create chat interface
function M.create_interface()
  return ui.create_interface()
end

-- Send message
function M.send_message()
  return input.send_message()
end

-- Close chat
function M.close()
  return ui.close()
end

-- Toggle chat
function M.toggle()
  return ui.toggle()
end

-- Add to chat
function M.add_to_chat(text)
  return ui.add_to_chat(text)
end

-- Update chat stream
function M.update_chat_stream(chunk)
  return streaming.update_chat_stream(chunk)
end

-- Process regular message
function M.process_regular_message(message)
  return messages.process_regular_message(message)
end

-- Handle complex reasoning
function M.handle_complex_reasoning(message)
  return messages.handle_complex_reasoning(message)
end

-- Handle buffer reference
function M.handle_buffer_reference(message)
  return messages.handle_buffer_reference(message)
end

-- Handle complex file request
function M.handle_complex_file_request(message)
  return messages.handle_complex_file_request(message)
end

-- Process LLM response
function M.process_llm_response(response, user_message)
  return streaming.process_llm_response(response, user_message)
end

-- Show help
function M.show_help()
  return commands.show_help()
end

-- Show buffer picker
function M.show_buffer_picker()
  return commands.show_buffer_picker()
end

-- Clear history
function M.clear_history()
  return commands.clear_history()
end

-- Get current buffer context
function M.get_current_buffer_context()
  return messages.get_current_buffer_context()
end

-- Get conversation context
function M.get_conversation_context()
  return messages.get_conversation_context()
end

-- Build enhanced prompt
function M.build_enhanced_prompt(user_message)
  return messages.build_enhanced_prompt(user_message)
end

return M
