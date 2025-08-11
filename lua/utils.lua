-- Utility functions for Flux.nvim
local M = {}

-- Add string trim function
function M.trim(s)
  return s:match("^%s*(.-)%s*$")
end

return M