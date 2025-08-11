local M = {}
local api = vim.api

-- Handle @READ command
function M.handle_read(path)
  local handle = require("ui.progress").start_read("Reading " .. path)
  path = path:trim()
  
  -- Handle special paths
  if path == "." or path == "./" then
    path = vim.fn.getcwd()
  elseif path == ".." then
    path = vim.fn.fnamemodify(vim.fn.getcwd(), ":h")
  end
  
  -- Check if path exists
  if vim.fn.isdirectory(path) == 1 then
    -- List directory contents
    local files = vim.fn.readdir(path)
    local result = "**Directory:** " .. path .. "\n\n"
    for _, file in ipairs(files) do
      local full_path = vim.fn.fnamemodify(path .. "/" .. file, ":p")
      if vim.fn.isdirectory(full_path) == 1 then
        result = result .. "📁 " .. file .. "/\n"
      else
        result = result .. "📄 " .. file .. "\n"
      end
    end
    require("ui.progress").complete(handle, "Directory listed")
    return result
  elseif vim.fn.filereadable(path) == 1 then
    -- Read file content
    local lines = vim.fn.readfile(path)
    local content = table.concat(lines, "\n")
    local filetype = vim.fn.fnamemodify(path, ":e")
    
    require("ui.progress").complete(handle, "File read")
    return string.format("```%s\n%s\n```", filetype, content)
  else
    require("ui.progress").error(handle, "File not found")
    return "**Error:** File or directory not found: " .. path
  end
end

-- Handle @CREATE command
function M.handle_create(filename, content)
  local handle = require("ui.progress").start_write("Creating " .. filename)
  
  -- Ensure directory exists
  local dir = vim.fn.fnamemodify(filename, ":h")
  if dir ~= "." and vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end
  
  -- Write file
  local success, err = pcall(vim.fn.writefile, vim.split(content, "\n"), filename)
  
  if success then
    require("ui.progress").complete(handle, "File created")
    return "File created successfully: " .. filename
  else
    require("ui.progress").error(handle, "Failed to create file")
    return "**Error:** Failed to create file: " .. (err or "Unknown error")
  end
end

-- Handle @UPDATE command
function M.handle_update(filename, content)
  local handle = require("ui.progress").start_write("Updating " .. filename)
  
  -- Check if file exists
  if vim.fn.filereadable(filename) == 0 then
    require("ui.progress").error(handle, "File not found")
    return "**Error:** File not found: " .. filename
  end
  
  -- Write file
  local success, err = pcall(vim.fn.writefile, vim.split(content, "\n"), filename)
  
  if success then
    require("ui.progress").complete(handle, "File updated")
    return "File updated successfully: " .. filename
  else
    require("ui.progress").error(handle, "Failed to update file")
    return "**Error:** Failed to update file: " .. (err or "Unknown error")
  end
end

-- Handle @EDIT command
function M.handle_edit(content)
  local handle = require("ui.progress").start_write("Editing current buffer")
  
  local current_buf = api.nvim_get_current_buf()
  if not current_buf or not api.nvim_buf_is_valid(current_buf) then
    require("ui.progress").error(handle, "No valid buffer")
    return "**Error:** No valid buffer to edit"
  end
  
  -- Split content into lines
  local lines = vim.split(content, "\n")
  
  -- Update buffer content
  local success, err = pcall(api.nvim_buf_set_lines, current_buf, 0, -1, false, lines)
  
  if success then
    require("ui.progress").complete(handle, "Buffer updated")
    return "Current buffer updated successfully"
  else
    require("ui.progress").error(handle, "Failed to update buffer")
    return "**Error:** Failed to update buffer: " .. (err or "Unknown error")
  end
end

-- Register the tool
local tools = require("tools")
tools.register("file_ops", M)

return M
