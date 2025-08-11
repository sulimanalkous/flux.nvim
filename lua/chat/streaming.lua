local M = {}

-- Temporary: delegate to old chat.lua until migration is complete
local old_chat = require("chat")

function M.setup()
  -- Will be implemented during migration
end

function M.update_chat_stream(chunk)
  return old_chat.update_chat_stream(chunk)
end

function M.process_llm_response(response, user_message)
  return old_chat.process_llm_response(response, user_message)
end

return M
