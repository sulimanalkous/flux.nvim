local M = {}

-- Temporary: delegate to old chat.lua until migration is complete
local old_chat = require("chat")

function M.setup()
  -- Will be implemented during migration
end

function M.show_help()
  return old_chat.show_help()
end

function M.show_buffer_picker()
  return old_chat.show_buffer_picker()
end

function M.clear_history()
  return old_chat.clear_history()
end

return M
