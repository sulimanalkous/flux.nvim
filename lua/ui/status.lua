local M = {}

-- Update status using fidget.nvim
function M.update_status(message, progress)
  -- Check if fidget.nvim is available
  local fidget = pcall(require, "fidget")
  if fidget then
    local fidget_module = require("fidget")
    if fidget_module.progress then
      fidget_module.progress.update(message, progress)
    end
  end
end

-- Clear status
function M.clear_status()
  local fidget = pcall(require, "fidget")
  if fidget then
    local fidget_module = require("fidget")
    if fidget_module.progress then
      fidget_module.progress.done()
    end
  end
end

-- Show AI status
function M.show_ai_status(status, details)
  local message = "🤖 " .. status
  if details then
    message = message .. ": " .. details
  end
  
  M.update_status(message, 0.5)
end

-- Show processing status
function M.show_processing_status(step, total_steps)
  local progress = total_steps and (step / total_steps) or 0.5
  local message = "🔄 Processing: " .. step
  if total_steps then
    message = message .. "/" .. total_steps
  end
  
  M.update_status(message, progress)
end

-- Show completion status
function M.show_completion_status(message)
  M.update_status("✅ " .. message, 1.0)
  vim.defer_fn(function()
    M.clear_status()
  end, 2000) -- Clear after 2 seconds
end

-- Show error status
function M.show_error_status(error_message)
  M.update_status("❌ Error: " .. error_message, 1.0)
  vim.defer_fn(function()
    M.clear_status()
  end, 3000) -- Clear after 3 seconds
end

return M
