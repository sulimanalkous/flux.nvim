local M = {}

local api = vim.api

-- Diff state
M.state = {
  diff_buf_original = nil,
  diff_buf_modified = nil,
  diff_win_original = nil,
  diff_win_modified = nil,
  original_content = nil,
  modified_content = nil,
  target_bufnr = nil,
  hint_win = nil,
  hint_buf = nil,
}

-- Show diff interface with before/after comparison
function M.show_diff(original_lines, modified_lines, target_bufnr, title)
  title = title or "Flux Code Diff"
  
  -- Store state
  M.state.original_content = original_lines
  M.state.modified_content = modified_lines
  M.state.target_bufnr = target_bufnr
  
  -- Create split windows
  M.create_diff_windows(title)
  
  -- Set content
  M.set_diff_content()
  
  -- Enable diff mode
  M.enable_diff_mode()
  
  -- Setup keymaps for diff interface
  M.setup_diff_keymaps()
end

-- Create split windows for diff
function M.create_diff_windows(title)
  -- Save current window
  local original_win = api.nvim_get_current_win()
  
  -- Create new tab for diff
  vim.cmd("tabnew")
  
  -- Create original content buffer with unique name
  M.state.diff_buf_original = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(M.state.diff_buf_original, "buftype", "nofile")
  api.nvim_buf_set_option(M.state.diff_buf_original, "modifiable", false)
  
  -- Try to set unique name, fallback to no name if it fails
  local original_name = title .. " - Original_" .. os.time() .. "_" .. math.random(1000, 9999)
  local success = pcall(api.nvim_buf_set_name, M.state.diff_buf_original, original_name)
  if not success then
    -- If naming fails, just leave it unnamed
    vim.notify("Could not name original diff buffer, continuing unnamed", vim.log.levels.WARN)
  end
  
  -- Create modified content buffer with unique name
  M.state.diff_buf_modified = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(M.state.diff_buf_modified, "buftype", "nofile")
  api.nvim_buf_set_option(M.state.diff_buf_modified, "modifiable", false)
  
  -- Try to set unique name, fallback to no name if it fails
  local modified_name = title .. " - Modified_" .. os.time() .. "_" .. math.random(1000, 9999)
  local success2 = pcall(api.nvim_buf_set_name, M.state.diff_buf_modified, modified_name)
  if not success2 then
    -- If naming fails, just leave it unnamed
    vim.notify("Could not name modified diff buffer, continuing unnamed", vim.log.levels.WARN)
  end
  
  -- Set up split layout
  vim.cmd("vsplit")
  
  -- Left window - original
  M.state.diff_win_original = api.nvim_get_current_win()
  api.nvim_win_set_buf(M.state.diff_win_original, M.state.diff_buf_original)
  
  -- Right window - modified
  vim.cmd("wincmd l")
  M.state.diff_win_modified = api.nvim_get_current_win()
  api.nvim_win_set_buf(M.state.diff_win_modified, M.state.diff_buf_modified)
  
  -- Add instruction header
  local instructions = {
    "# " .. title,
    "",
    "**Quick Actions:**",
    "- `ct` - Accept changes (theirs) ✅",
    "- `co` - Keep original (ours) ❌", 
    "- `ca` - Accept all changes ✅",
    "- `q` - Close without applying ❌",
    "",
    "**Advanced:**",
    "- `]c`/`[c` - Next/previous change",
    "- `:diffget` - Get change from other buffer",
    "- `:diffput` - Put change to other buffer",
    "",
    "---",
    "",
  }
  
  -- Add instructions to both buffers
  api.nvim_buf_set_option(M.state.diff_buf_original, "modifiable", true)
  api.nvim_buf_set_lines(M.state.diff_buf_original, 0, 0, false, instructions)
  
  api.nvim_buf_set_option(M.state.diff_buf_modified, "modifiable", true) 
  api.nvim_buf_set_lines(M.state.diff_buf_modified, 0, 0, false, instructions)
end

-- Set content in diff buffers
function M.set_diff_content()
  local instruction_lines = 9 -- Number of instruction lines we added
  
  -- Set original content
  api.nvim_buf_set_option(M.state.diff_buf_original, "modifiable", true)
  api.nvim_buf_set_lines(M.state.diff_buf_original, instruction_lines, -1, false, M.state.original_content)
  api.nvim_buf_set_option(M.state.diff_buf_original, "modifiable", false)
  
  -- Set modified content (keep modifiable for user edits)
  api.nvim_buf_set_option(M.state.diff_buf_modified, "modifiable", true)
  api.nvim_buf_set_lines(M.state.diff_buf_modified, instruction_lines, -1, false, M.state.modified_content)
  -- Keep this buffer modifiable so users can edit before accepting
  
  -- Set filetype to match original buffer if available
  if M.state.target_bufnr and api.nvim_buf_is_valid(M.state.target_bufnr) then
    local original_ft = vim.bo[M.state.target_bufnr].filetype
    vim.bo[M.state.diff_buf_original].filetype = original_ft
    vim.bo[M.state.diff_buf_modified].filetype = original_ft
  end
end

-- Enable diff mode for both windows
function M.enable_diff_mode()
  -- Focus original window and enable diff
  api.nvim_set_current_win(M.state.diff_win_original)
  vim.cmd("diffthis")
  
  -- Focus modified window and enable diff
  api.nvim_set_current_win(M.state.diff_win_modified)
  vim.cmd("diffthis")
  
  -- Set diff options
  vim.opt_local.wrap = false
  vim.opt_local.scrollbind = true
  vim.opt_local.cursorbind = true
  
  -- Go back to original window
  api.nvim_set_current_win(M.state.diff_win_original)
  vim.opt_local.wrap = false
  vim.opt_local.scrollbind = true
  vim.opt_local.cursorbind = true
end

-- Setup keymaps for diff interface
function M.setup_diff_keymaps()
  local opts = { buffer = true, silent = true }
  
  -- Accept changes (multiple bindings for convenience)
  vim.keymap.set("n", "<leader>da", function()
    M.accept_changes()
  end, vim.tbl_extend("force", opts, { desc = "Accept diff changes" }))
  
  vim.keymap.set("n", "ct", function()
    M.accept_changes()
  end, vim.tbl_extend("force", opts, { desc = "Accept changes (theirs)" }))
  
  -- Reject changes  
  vim.keymap.set("n", "<leader>dr", function()
    M.reject_changes()
  end, vim.tbl_extend("force", opts, { desc = "Reject diff changes" }))
  
  vim.keymap.set("n", "co", function()
    M.reject_changes()
  end, vim.tbl_extend("force", opts, { desc = "Keep original (ours)" }))
  
  -- Quick close
  vim.keymap.set("n", "q", function()
    M.close_diff()
  end, vim.tbl_extend("force", opts, { desc = "Close diff" }))
  
  -- Copy all changes from modified to original (accept all)
  vim.keymap.set("n", "<leader>dA", function()
    M.accept_all_changes()
  end, vim.tbl_extend("force", opts, { desc = "Accept all changes" }))
  
  vim.keymap.set("n", "ca", function()
    M.accept_changes() -- For now, same as ct - could implement true "accept all" later
  end, vim.tbl_extend("force", opts, { desc = "Accept all changes" }))
  
  -- Additional diff navigation
  vim.keymap.set("n", "]c", "]c", vim.tbl_extend("force", opts, { desc = "Next diff" }))
  vim.keymap.set("n", "[c", "[c", vim.tbl_extend("force", opts, { desc = "Previous diff" }))
  
  -- Setup floating hints when cursor is in diff buffers
  M.setup_floating_hints()
end

-- Create floating keymap hints
function M.create_floating_hints()
  if M.state.hint_win and api.nvim_win_is_valid(M.state.hint_win) then
    return -- Already showing
  end
  
  local current_win = api.nvim_get_current_win()
  local is_in_diff = (current_win == M.state.diff_win_original or current_win == M.state.diff_win_modified)
  
  if not is_in_diff then
    return
  end
  
  -- Create hint content
  local hint_lines = {
    " 🔧 Diff Actions ",
    "",
    " ct  Accept changes (theirs) ✅",
    " co  Keep original (ours)    ❌", 
    " ca  Accept all changes      ✅",
    " q   Close diff              ❌",
    "",
    " ]c/[c  Next/Prev change",
  }
  
  -- Create floating buffer
  local hint_buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(hint_buf, "buftype", "nofile")
  api.nvim_buf_set_option(hint_buf, "filetype", "")
  api.nvim_buf_set_lines(hint_buf, 0, -1, false, hint_lines)
  
  -- Calculate position (top-right of current window)
  local win_config = api.nvim_win_get_config(current_win)
  local win_width = api.nvim_win_get_width(current_win)
  local win_height = api.nvim_win_get_height(current_win)
  
  local float_config = {
    relative = "win",
    win = current_win,
    width = 30,
    height = #hint_lines,
    col = win_width - 32,
    row = 1,
    style = "minimal",
    border = "rounded",
    title = "",
    title_pos = "center",
  }
  
  -- Create floating window
  M.state.hint_win = api.nvim_open_win(hint_buf, false, float_config)
  M.state.hint_buf = hint_buf
  
  -- Set highlight
  api.nvim_win_set_option(M.state.hint_win, "winhl", "Normal:FloatBorder,FloatBorder:FloatBorder")
  
  -- Auto-hide after 3 seconds
  vim.defer_fn(function()
    M.hide_floating_hints()
  end, 3000)
end

-- Hide floating hints
function M.hide_floating_hints()
  if M.state.hint_win and api.nvim_win_is_valid(M.state.hint_win) then
    api.nvim_win_close(M.state.hint_win, true)
  end
  if M.state.hint_buf and api.nvim_buf_is_valid(M.state.hint_buf) then
    api.nvim_buf_delete(M.state.hint_buf, { force = true })
  end
  M.state.hint_win = nil
  M.state.hint_buf = nil
end

-- Setup floating hints with cursor detection
function M.setup_floating_hints()
  -- Create autocommands for both diff buffers
  local augroup = api.nvim_create_augroup("FluxDiffHints", { clear = true })
  
  -- Show hints when entering diff buffers
  api.nvim_create_autocmd({"BufEnter", "CursorMoved"}, {
    group = augroup,
    callback = function()
      local current_buf = api.nvim_get_current_buf()
      if current_buf == M.state.diff_buf_original or current_buf == M.state.diff_buf_modified then
        -- Small delay to avoid spam
        vim.defer_fn(function()
          M.create_floating_hints()
        end, 100)
      else
        M.hide_floating_hints()
      end
    end,
  })
  
  -- Hide hints when leaving diff buffers
  api.nvim_create_autocmd({"BufLeave"}, {
    group = augroup,
    callback = function()
      local current_buf = api.nvim_get_current_buf()
      if current_buf == M.state.diff_buf_original or current_buf == M.state.diff_buf_modified then
        M.hide_floating_hints()
      end
    end,
  })
end

-- Accept changes and apply to original buffer
function M.accept_changes()
  if not M.state.target_bufnr or not api.nvim_buf_is_valid(M.state.target_bufnr) then
    vim.notify("Target buffer is no longer valid", vim.log.levels.ERROR)
    return
  end
  
  -- Get current content from the modified buffer (user might have edited it)
  local instruction_lines = 9
  if M.state.diff_buf_modified and api.nvim_buf_is_valid(M.state.diff_buf_modified) then
    local current_content = api.nvim_buf_get_lines(M.state.diff_buf_modified, instruction_lines, -1, false)
    api.nvim_buf_set_lines(M.state.target_bufnr, 0, -1, false, current_content)
    vim.notify("Changes accepted and applied to buffer!", vim.log.levels.INFO)
  else
    vim.notify("Modified buffer is no longer valid", vim.log.levels.ERROR)
    return
  end
  
  M.close_diff()
end

-- Accept all changes from modified buffer
function M.accept_all_changes()
  -- Go to modified buffer
  api.nvim_set_current_win(M.state.diff_win_modified)
  
  -- Select all content (skip instructions)
  local instruction_lines = 9
  local total_lines = api.nvim_buf_line_count(M.state.diff_buf_modified)
  vim.cmd(string.format("%d,%ddiffput", instruction_lines + 1, total_lines))
  
  vim.notify("All changes copied to original buffer", vim.log.levels.INFO)
end

-- Reject changes and close diff
function M.reject_changes()
  vim.notify("Changes rejected", vim.log.levels.INFO)
  M.close_diff()
end

-- Close diff interface
function M.close_diff()
  -- Hide floating hints
  M.hide_floating_hints()
  
  -- Clean up autocommands
  pcall(api.nvim_del_augroup_by_name, "FluxDiffHints")
  
  -- Disable diff mode
  if M.state.diff_win_original and api.nvim_win_is_valid(M.state.diff_win_original) then
    api.nvim_set_current_win(M.state.diff_win_original)
    vim.cmd("diffoff")
  end
  
  if M.state.diff_win_modified and api.nvim_win_is_valid(M.state.diff_win_modified) then
    api.nvim_set_current_win(M.state.diff_win_modified)
    vim.cmd("diffoff")
  end
  
  -- Close tab
  vim.cmd("tabclose")
  
  -- Reset state
  M.state = {
    diff_buf_original = nil,
    diff_buf_modified = nil,
    diff_win_original = nil,
    diff_win_modified = nil,
    original_content = nil,
    modified_content = nil,
    target_bufnr = nil,
    hint_win = nil,
    hint_buf = nil,
  }
end

-- Utility function to show diff for file edit
function M.show_edit_diff(target_bufnr, new_content, title)
  if not target_bufnr or not api.nvim_buf_is_valid(target_bufnr) then
    vim.notify("Invalid target buffer for diff", vim.log.levels.ERROR)
    return false
  end
  
  local original_lines = api.nvim_buf_get_lines(target_bufnr, 0, -1, false)
  local modified_lines = type(new_content) == "string" and vim.split(new_content, "\n") or new_content
  
  M.show_diff(original_lines, modified_lines, target_bufnr, title or "Code Edit Diff")
  return true
end

return M