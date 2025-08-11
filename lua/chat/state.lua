local M = {}

-- Chat state (shared across all chat modules)
M.state = {
  chat_buf = nil,
  input_buf = nil,
  pinned_buffer = nil,
  conversation_history = {},
  is_streaming = false
}

return M
