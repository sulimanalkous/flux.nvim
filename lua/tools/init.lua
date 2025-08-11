local M = {}

-- Tools registry
M.tools = {}

-- Register a tool
function M.register(name, tool)
  M.tools[name] = tool
end

-- Get a tool
function M.get_tool(name)
  return M.tools[name]
end

-- Initialize tools
function M.setup()
  -- Load all tools
  require("tools.file_ops")
  require("tools.buffer_ref")
  require("tools.project_index")
end

return M
