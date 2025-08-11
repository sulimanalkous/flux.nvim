local M = {}

-- Temporary: delegate to old chat.lua until migration is complete
local old_chat = require("chat")

function M.setup()
  -- Will be implemented during migration
end

function M.process_regular_message(message)
  return old_chat.process_regular_message(message)
end

function M.handle_complex_reasoning(message)
  return old_chat.handle_complex_reasoning(message)
end

function M.handle_buffer_reference(message)
  return old_chat.handle_buffer_reference(message)
end

function M.handle_complex_file_request(message)
  return old_chat.handle_complex_file_request(message)
end

function M.get_current_buffer_context()
  return old_chat.get_current_buffer_context()
end

function M.get_conversation_context()
  return old_chat.get_conversation_context()
end

function M.build_enhanced_prompt(user_message)
  return old_chat.build_enhanced_prompt(user_message)
end

return M
