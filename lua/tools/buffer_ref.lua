local M = {}
local api = vim.api

-- Handle #{buffer} reference
function M.handle_buffer_reference(message)
  local context = M.get_current_buffer_context()
  if context then
    -- Create buffer reference with pinned indicator
    local pin_indicator = context.is_pinned and "📌" or "🔄"
    local buffer_reference = string.format("<buffer>%s%s</buffer>", pin_indicator, context.basename)
    message = message:gsub("#{buffer}", buffer_reference)
    
    -- Add the buffer content to the enhanced prompt
    local buffer_content = table.concat(context.lines, "\n")
    local enhanced_message = require("chat.messages").build_enhanced_prompt(message)
    
    -- Add buffer content to prompt
    enhanced_message = enhanced_message .. string.format([[

Referenced Buffer (%s%s):
```%s
%s
```]], context.is_pinned and "pinned: " or "current: ", context.basename, context.filetype, buffer_content)
    
    -- Add user message to chat (showing the substituted version)
    require("chat.ui").add_to_chat("**You:** " .. message)
    require("chat.ui").add_to_chat("")
    require("chat.ui").add_to_chat("**LLM:** *thinking...*")
    
    -- Start progress indicator
    local handle = require("ui.progress").start_chat("Processing request with buffer context...")
    
    -- Send to LLM with buffer context
    local providers = require("providers")
    local provider = providers.get_provider()
    provider:generate(enhanced_message, function(response, err)
      if err or not response then
        require("ui.progress").error(handle, "No response received: " .. (err or ""))
      else
        require("ui.progress").complete(handle, "Response received")
        -- Add buffer reference to the end (only if it's valid)
        if buffer_reference and buffer_reference ~= vim.NIL then
          response = response .. string.format("\n\n%s", buffer_reference)
        end
      end
      
      -- Process response for special commands
      require("chat.streaming").process_llm_response(response, message)
    end)
  else
    require("chat.ui").add_to_chat("**You:** " .. message)
    require("chat.ui").add_to_chat("")
    require("chat.ui").add_to_chat("**System:** No buffer is currently open to reference.")
    require("chat.ui").add_to_chat("")
    require("chat.input").add_input_prompt()
  end
end

-- Get current buffer context
function M.get_current_buffer_context()
  local current_buf = api.nvim_get_current_buf()
  if not current_buf or not api.nvim_buf_is_valid(current_buf) then
    return nil
  end

  local filename = api.nvim_buf_get_name(current_buf)
  if not filename or filename == "" then
    return nil
  end

  local basename = vim.fn.fnamemodify(filename, ":t")
  local filetype = vim.bo[current_buf].filetype or ""
  local lines = api.nvim_buf_get_lines(current_buf, 0, -1, false) or {}
  
  -- Check if this is the pinned buffer
  local chat = require("chat")
  local is_pinned = (chat.state.pinned_buffer == current_buf)

  return {
    bufnr = current_buf,
    filename = filename,
    basename = basename,
    filetype = filetype,
    lines = lines,
    is_pinned = is_pinned
  }
end

-- Register the tool
local tools = require("tools")
tools.register("buffer_ref", M)

return M
