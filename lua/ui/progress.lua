local M = {}

-- Try to load fidget, gracefully handle if not available
local has_fidget, progress = pcall(require, "fidget.progress")

-- Storage for active progress handles
M.handles = {}

function M.is_available()
  return has_fidget
end

-- Create a new progress handle for an operation
function M.start(operation_type, message, id)
  if not has_fidget then
    -- Fallback to simple notification
    vim.notify(M.get_operation_title(operation_type) .. ": " .. (message or "Starting..."), vim.log.levels.INFO)
    return { fallback = true, title = M.get_operation_title(operation_type) }
  end

  local title = M.get_operation_title(operation_type)
  local handle = progress.handle.create({
    title = title,
    message = message or "Starting...",
    lsp_client = {
      name = "Flux.nvim",
    },
  })

  if id then
    M.handles[id] = handle
  end

  return handle
end

-- Update progress message
function M.update(handle, message)
  if handle then
    if handle.fallback then
      -- Just show notification for fallback
      vim.notify(handle.title .. ": " .. message, vim.log.levels.INFO)
    elseif has_fidget then
      handle.message = message
    end
  end
end

-- Complete progress with success
function M.complete(handle, message)
  if handle then
    if handle.fallback then
      vim.notify(handle.title .. ": " .. (message or "✅ Completed"), vim.log.levels.INFO)
    elseif has_fidget then
      handle.message = message or "✅ Completed"
      handle:finish()
    end
  end
end

-- Complete progress with error
function M.error(handle, message)
  if handle then
    if handle.fallback then
      vim.notify(handle.title .. ": " .. (message or "❌ Error"), vim.log.levels.ERROR)
    elseif has_fidget then
      handle.message = message or "❌ Error"
      handle:finish()
    end
  end
end

-- Cancel progress
function M.cancel(handle, message)
  if handle then
    if handle.fallback then
      vim.notify(handle.title .. ": " .. (message or "⏹️ Cancelled"), vim.log.levels.WARN)
    elseif has_fidget then
      handle.message = message or "⏹️ Cancelled"
      handle:finish()
    end
  end
end

-- Get progress handle by ID
function M.get_handle(id)
  return M.handles[id]
end

-- Remove and return handle by ID
function M.pop_handle(id)
  local handle = M.handles[id]
  M.handles[id] = nil
  return handle
end

-- Get appropriate title based on operation type
function M.get_operation_title(operation_type)
  local titles = {
    chat = "🤖 AI Chat",
    completion = "💡 Code Completion",
    edit = "✏️ Editing Code",
    read = "📖 Reading File",
    list = "📁 Listing Directory",
    fix = "🔧 Fixing Code",
    explain = "💭 Explaining Code",
  }
  
  return titles[operation_type] or "🚀 Flux Operation"
end

-- Convenience functions for common operations
function M.start_chat(message, id)
  return M.start("chat", message, id)
end

function M.start_completion(message, id)
  return M.start("completion", message, id)
end

function M.start_edit(message, id)
  return M.start("edit", message, id)
end

function M.start_read(message, id)
  return M.start("read", message, id)
end

function M.start_fix(message, id)
  return M.start("fix", message, id)
end

return M