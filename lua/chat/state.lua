local M = {}

-- Chat state (shared across all chat modules)
M.state = {
  chat_buf = nil,
  input_buf = nil,
  status_buf = nil,
  container_buf = nil,
  container_win = nil,
  result_win = nil,
  input_win = nil,
  status_win = nil,
  pinned_buffer = nil,
  conversation_history = {},
  is_streaming = false,
  current_message_id = nil, -- Added for unique message tracking
  processing_message = false -- Added for robust send protection
}

return M
