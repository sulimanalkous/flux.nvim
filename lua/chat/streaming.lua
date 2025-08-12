local M = {}
local api = vim.api

-- Chat state (shared across modules)
local state = require("chat.state")

function M.setup()
  -- Will be implemented during migration
end

-- Update chat with a streaming response chunk
function M.update_chat_stream(chunk)
  if not state.state.chat_buf or not api.nvim_buf_is_valid(state.state.chat_buf) then return end

  -- Filter out vim.NIL chunks
  if not chunk or chunk == vim.NIL or tostring(chunk) == "vim.NIL" then
    return
  end

  local lines = api.nvim_buf_get_lines(state.state.chat_buf, 0, -1, false)
  
  if state.state.is_streaming == false then
    -- First chunk, replace "thinking..."
    state.state.is_streaming = true
    for i = #lines, 1, -1 do
      if lines[i]:match("%*thinking%.%.%.%*") or lines[i]:match("%*processing%.%.%.%*") then
        lines[i] = "**LLM:** " .. chunk
        break
      end
    end
  else
    -- Subsequent chunks, append to last line
    if #lines > 0 then
      lines[#lines] = lines[#lines] .. chunk
    end
  end

  -- To handle newlines in the chunk, we split the last line
  if #lines > 0 then
    local last_line_chunks = vim.split(lines[#lines], "\n")
    if #last_line_chunks > 1 then
      lines[#lines] = last_line_chunks[1]
      for i = 2, #last_line_chunks do
        table.insert(lines, last_line_chunks[i])
      end
    end
  end

  api.nvim_buf_set_lines(state.state.chat_buf, 0, -1, false, lines)
  require("chat.ui").scroll_to_bottom()
end

-- Update chat with final response
function M.update_chat_response_full(response)
  -- Validate chat buffer exists and is valid
  if not state.state.chat_buf or not api.nvim_buf_is_valid(state.state.chat_buf) then
    vim.notify("Chat buffer is invalid, cannot update response", vim.log.levels.ERROR)
    return
  end
  
  local lines = api.nvim_buf_get_lines(state.state.chat_buf, 0, -1, false)
  
  -- Remove "thinking..." line (look for it more carefully)
  for i = #lines, 1, -1 do
    if lines[i]:match("thinking%.%.%.") or lines[i]:match("processing%.%.%.") then
      table.remove(lines, i)
      break
    end
  end

  -- Split response into individual lines to avoid newline issues
  local response_lines = vim.split(response, "\n")
  
  -- Add LLM prefix to first line
  if #response_lines > 0 then
    table.insert(lines, "**LLM:** " .. response_lines[1])
    -- Add remaining lines
    for i = 2, #response_lines do
      table.insert(lines, response_lines[i])
    end
  else
    table.insert(lines, "**LLM:** " .. response)
  end
  
  table.insert(lines, "")
  table.insert(lines, "---")
  table.insert(lines, "")

  api.nvim_buf_set_lines(state.state.chat_buf, 0, -1, false, lines)

  -- Auto-scroll to bottom
  require("chat.ui").scroll_to_bottom()
end

-- Process LLM response and handle special commands
function M.process_llm_response(response, user_message)
  if not response then
    M.update_chat_response_full("No response received")
    return
  end

  -- Handle vim.NIL values that might come from the LLM
  if response == vim.NIL then
    M.update_chat_response_full("Error: Received invalid response from LLM")
    return
  end

  -- Convert response to string and handle any nil values
  response = tostring(response)
  
  -- Clean up any vim.NIL references that might have slipped through
  response = response:gsub("vim%.NIL", ""):gsub("^%s*", ""):gsub("%s*$", "")
  
  local processed_response = ""
  local remaining_text = response
  
  -- Process @UPDATE commands (for existing files)
  if remaining_text:find("@UPDATE") then
    vim.notify("Flux.nvim: Found @UPDATE command in response", vim.log.levels.INFO)
  end
  while remaining_text:find("@UPDATE") do
    local before_update, filename, after_update = remaining_text:match("^(.-)@UPDATE%s+(.-)%s*\n(.*)$")
    if not filename then
      before_update, filename = remaining_text:match("^(.-)@UPDATE%s+(.-)%s*$")
      after_update = ""
    end
    
    if before_update and filename then
      processed_response = processed_response .. before_update
      
      -- Extract file content (look for code block)
      local file_content = ""
      if after_update:match("^%s*```") then
        -- Extract from code block
        file_content = after_update:match("^%s*```.-\n(.-)\n```")
        remaining_text = after_update:gsub("^%s*```.-\n.-\n```", "", 1)
      else
        -- Take everything until next @ command or end
        file_content = after_update:match("^(.-)\n@") or after_update
        remaining_text = after_update:gsub("^.-\n@", "@", 1)
      end
      
      local file_ops = require("tools").get_tool("file_ops")
      local update_result = file_ops.handle_update(filename:trim(), file_content)
      processed_response = processed_response .. "\n**[📝 Updated file]** " .. update_result .. "\n\n"
      vim.notify("Flux.nvim: File updated: " .. filename:trim(), vim.log.levels.INFO)
    else
      break
    end
  end
  
  -- Process @CREATE commands
  while remaining_text:find("@CREATE") do
    local before_create, filename, after_create = remaining_text:match("^(.-)@CREATE%s+(.-)%s*\n(.*)$")
    if not filename then
      before_create, filename = remaining_text:match("^(.-)@CREATE%s+(.-)%s*$")
      after_create = ""
    end
    
    if before_create and filename then
      processed_response = processed_response .. before_create
      
      -- Extract file content (look for code block)
      local file_content = ""
      if after_create:match("^%s*```") then
        -- Extract from code block
        file_content = after_create:match("^%s*```.-\n(.-)\n```")
        remaining_text = after_create:gsub("^%s*```.-\n.-\n```", "", 1)
      else
        -- Take everything until next @ command or end
        file_content = after_create:match("^(.-)\n@") or after_create
        remaining_text = after_create:gsub("^.-\n@", "@", 1)
      end
      
      local file_ops = require("tools").get_tool("file_ops")
      local create_result = file_ops.handle_create(filename:trim(), file_content)
      processed_response = processed_response .. "\n**[📄 Created file]** " .. create_result .. "\n\n"
    else
      break
    end
  end
  
  -- Process @EDIT commands
  while remaining_text:find("@EDIT") do
    local before_edit, after_edit = remaining_text:match("^(.-)@EDIT(.*)$")
    if before_edit then
      processed_response = processed_response .. before_edit
      
      -- Extract code content (look for code block or take everything until next @command)
      local code_content = ""
      if after_edit:match("^%s*```") then
        -- Extract from code block
        code_content = after_edit:match("^%s*```.-\n(.-)\n```")
        remaining_text = after_edit:gsub("^%s*```.-\n.-\n```", "", 1)
      else
        -- Take everything until next @ command or end
        code_content = after_edit:match("^(.-)\n@") or after_edit
        remaining_text = after_edit:gsub("^.-\n@", "@", 1)
      end
      
      local file_ops = require("tools").get_tool("file_ops")
      local edit_result = file_ops.handle_edit(code_content)
      processed_response = processed_response .. "\n**[✏️ Edited current file]** " .. edit_result .. "\n\n"
    else
      break
    end
  end
  
  -- Process @READ commands  
  while remaining_text:find("@READ") do
    local before_read, path, after_read = remaining_text:match("^(.-)@READ%s+(.-)%s*\n(.*)$")
    if not path then
      before_read, path = remaining_text:match("^(.-)@READ%s+(.-)%s*$")
      after_read = ""
    end
    
    if before_read and path then
      processed_response = processed_response .. before_read
      local file_ops = require("tools").get_tool("file_ops")
      local read_result = file_ops.handle_read(path)
      processed_response = processed_response .. "\n**[📖 Reading " .. path .. "]**\n" .. read_result .. "\n\n"
      
      -- If user asked for understanding/analysis, send content back to AI
      if user_message and (user_message:lower():match("understand") or user_message:lower():match("analyze") or user_message:lower():match("tell me")) then
        -- Extract just the file content (remove markdown formatting)
        local file_content = read_result:gsub("```\n", ""):gsub("```", ""):trim()
        if file_content and #file_content > 0 then
          -- Send follow-up request to AI for analysis
          vim.defer_fn(function()
            local analysis_prompt = "Based on this file content, please analyze and explain what you understand:\n\n" .. file_content
            local providers = require("providers")
            local provider = providers.get_provider()
            provider:generate(analysis_prompt, function(analysis)
              if analysis then
                require("chat.ui").add_to_chat("")
                require("chat.ui").add_to_chat("**Analysis:** " .. analysis)
                require("chat.ui").add_to_chat("")
              end
            end)
          end, 100) -- Small delay to let the read result show first
        end
      end
      
      remaining_text = after_read or ""
    else
      break
    end
  end
  
  -- Process @LIST commands
  while remaining_text:find("@LIST") do
    local before_list, path, after_list = remaining_text:match("^(.-)@LIST%s+(.-)%s*\n(.*)$")
    if not path then
      before_list, path = remaining_text:match("^(.-)@LIST%s+(.-)%s*$")
      after_list = ""
    end
    
    if before_list and path then
      processed_response = processed_response .. before_list
      local file_ops = require("tools").get_tool("file_ops")
      local list_result = file_ops.handle_read(path)
      processed_response = processed_response .. "\n**[📁 Listing " .. path .. "]**\n" .. list_result .. "\n\n"
      remaining_text = after_list or ""
    else
      break
    end
  end
  
  -- Add any remaining text
  processed_response = processed_response .. remaining_text

  -- If processed_response is empty, use the original response
  if processed_response:trim() == "" then
    processed_response = response
  end

  -- Final cleanup of any vim.NIL references
  processed_response = processed_response:gsub("vim%.NIL", ""):gsub("^%s*", ""):gsub("%s*$", "")

  M.update_chat_response_full(processed_response:trim())
  
  -- Save to conversation history for memory
  require("chat.messages").add_to_history(user_message or "", processed_response:trim())
  
  -- Add input prompt for next message
  require("chat.ui").add_to_chat("")
  require("chat.input").add_input_prompt()
end

return M
