local M = {}
local api = vim.api

-- Chat state (shared across modules)
local state = require("chat.state")

function M.setup()
  -- Will be implemented during migration
end

-- Process regular message
function M.process_regular_message(message)
  -- Check if this is the current message being processed
  local current_id = state.state.current_message_id
  if not current_id then
    vim.notify("Flux.nvim: No message ID found, skipping", vim.log.levels.WARN)
    return
  end
  
  local handle = require("ui.progress").start_chat("Processing request...", "chat_" .. os.time())

  require("chat.ui").add_to_chat("**LLM:** *thinking...*")

  local enhanced_message_base = M.build_enhanced_prompt(message)
  local full_response_chunks = {}
  state.state.is_streaming = false -- Reset streaming state

  -- Step 1: Get embedding for the user's query
  require("ui.progress").update(handle, "Generating query embedding...")
  local providers = require("providers")
  local provider = providers.get_provider()
  
  provider:embed(message, function(query_embedding, err_embed)
    if err_embed or not query_embedding then
      vim.notify("Flux.nvim: Failed to get query embedding: " .. (err_embed or "Unknown error"), vim.log.levels.WARN)
      vim.notify("Flux.nvim: Using FALLBACK path (no embedding) (ID: " .. (state.state.current_message_id or "none") .. ")", vim.log.levels.DEBUG)
      -- Fallback to non-augmented prompt if embedding fails
      local fallback_prompt = enhanced_message_base .. "\n\n**Note**: Project context unavailable due to embedding service issue. Please respond based on general knowledge and ask the user to run :FluxIndexProject if they need project-specific help."
      provider:stream(fallback_prompt,
        function(chunk) 
          require("ui.progress").complete(handle, "Receiving response...") 
          require("chat.streaming").update_chat_stream(chunk) 
          table.insert(full_response_chunks, chunk) 
        end,
        function(success, reason) 
          vim.notify("Flux.nvim: Fallback stream finish called with success: " .. tostring(success) .. " (ID: " .. (state.state.current_message_id or "none") .. ")", vim.log.levels.DEBUG)
          M.handle_stream_finish(success, reason, message, full_response_chunks) 
        end
      )
      return
    end
    
    vim.notify("Flux.nvim: Using NORMAL path (with embedding)", vim.log.levels.DEBUG)

    -- Step 2: Find relevant chunks from project index
    require("ui.progress").update(handle, "Finding relevant context...")
    local project_index = require("tools").get_tool("project_index")
    local relevant_chunks = project_index.find_relevant_chunks(query_embedding, 5) -- Get top 5 for better coverage

    local context_string = ""
    if #relevant_chunks > 0 then
      context_string = "\n\n**📁 PROJECT CONTEXT (Use this information to understand the project):**\n"
      for i, chunk_info in ipairs(relevant_chunks) do
        local relative_path = vim.fn.fnamemodify(chunk_info.file_path, ":.")
        context_string = context_string .. string.format("📄 File %d: %s\n```\n%s\n```\n", i, relative_path, chunk_info.text)
      end
      context_string = context_string .. "\n**IMPORTANT**: Use the above project context to answer the user's question about this project. This is the actual code and documentation from their project.\n\n"
    else
      -- Debug: Log when no chunks are found
      vim.notify("Flux.nvim: No relevant project context found. Query: " .. message:sub(1, 50), vim.log.levels.DEBUG)
      -- Add a note to the prompt about missing context
      context_string = "\n\n**Note**: No project context found. Please respond based on general knowledge and ask the user to run :FluxIndexProject if they need project-specific help.\n\n"
    end

    -- Step 3: Augment the prompt
    local augmented_prompt = context_string .. enhanced_message_base

    -- Step 4: Send to LLM with augmented prompt
    require("ui.progress").update(handle, "Sending augmented request to LLM...")
    vim.notify("Flux.nvim: Starting LLM stream for message: " .. message:sub(1, 30) .. " (ID: " .. (state.state.current_message_id or "none") .. ")", vim.log.levels.DEBUG)
    provider:stream(augmented_prompt,
      function(chunk) 
        require("ui.progress").complete(handle, "Receiving response...") 
        require("chat.streaming").update_chat_stream(chunk) 
        table.insert(full_response_chunks, chunk) 
      end,
      function(success, reason) 
        vim.notify("Flux.nvim: Stream finish called with success: " .. tostring(success) .. " (ID: " .. (state.state.current_message_id or "none") .. ")", vim.log.levels.DEBUG)
        M.handle_stream_finish(success, reason, message, full_response_chunks) 
      end
    )
  end)
end

-- Helper function to handle stream finish (extracted for clarity)
function M.handle_stream_finish(success, reason, user_message, full_response_chunks)
  -- Check if this is the current message being processed
  local current_id = state.state.current_message_id
  if not current_id then
    vim.notify("Flux.nvim: Stream finish called without message ID, skipping", vim.log.levels.WARN)
    return
  end
  
  if not success then
    require("chat.streaming").update_chat_stream("\n\n**Error:** " .. reason)
  end
  
  require("chat.ui").add_to_chat("\n\n---")
  require("chat.ui").add_to_chat("")
  state.state.is_streaming = false
  state.state.processing_message = false
  state.state.current_message_id = nil -- Clear the message ID
  -- Save full response to history
  local full_response = table.concat(full_response_chunks, "")
  M.add_to_history(user_message, full_response)
  -- Add input prompt for next message
  require("chat.input").add_input_prompt()
end

-- Build enhanced prompt with context and capabilities  
function M.build_enhanced_prompt(user_message)
  local context = M.get_current_buffer_context()
  
  -- Ensure context is valid
  if context and (not context.filename or context.filename == "" or context.filename == vim.NIL) then
    context = nil
  end
  
  local prompt = [[You are an intelligent AI coding assistant and thinking partner for the Flux.nvim plugin project. You should act like a helpful colleague who can reason, plan, and work with the user to solve problems together.

**IMPORTANT**: You are specifically working with the Flux.nvim Neovim plugin codebase. When users ask about "flux" or "flux.nvim", they are referring to THIS specific Neovim plugin, not the general Flux framework or any other Flux-related technology.

**Your Personality & Approach:**
- Think step-by-step and explain your reasoning
- Ask clarifying questions when needed
- Be conversational and natural, like talking to a friend
- Show enthusiasm for solving problems together
- Admit when you're unsure and suggest alternatives
- Build on previous conversations and maintain context
- Be proactive in suggesting improvements or next steps

**Your Capabilities:**
- Deep understanding of code and software development
- Ability to reason about complex problems
- Project-wide context awareness
- File operations and code editing
- Code review and improvement suggestions
- Debugging and problem-solving
- Planning and architecture discussions

**How to Respond:**
1. **For general questions**: Respond conversationally, think out loud, and engage naturally
2. **For coding tasks**: Think through the problem, explain your approach, then implement
3. **For file operations**: Use the special commands when needed, but explain what you're doing
4. **For complex problems**: Break them down, plan step-by-step, and work through them methodically

**Special File Operation Commands** (use only when performing actions):
- @EDIT - Edit current file with new code
- @CREATE filename.ext - Create new file
- @UPDATE filename.ext - Update existing file  
- @READ path/to/file - Read file content
- @LIST directory/ - List directory contents

**Current Context:]]

  if context and context.filename and context.filename ~= "" then
    prompt = prompt .. string.format([[
- **Current file**: %s (%s)
- **File type**: %s
- **Content preview** (first 20 lines):
```%s
%s
```

]], context.basename, context.filename, context.filetype, context.filetype, 
    table.concat(vim.list_slice(context.lines, 1, 20), "\n"))
  else
    prompt = prompt .. "\n- No file currently open\n\n"
  end

  -- Add conversation history for memory
  local history = M.get_conversation_context()
  if history ~= "" then
    prompt = prompt .. history
  end

  prompt = prompt .. "**Current request**: " .. user_message .. 
"\n\nRemember our previous conversation and build upon it. Think through this request step-by-step and respond naturally as a helpful coding partner." ..
"\n\n**RESPONSE STYLE**: For general questions, project discussions, and explanations, respond conversationally without using @COMMAND format. Only use @COMMAND format when you need to perform actual file operations (read, edit, create, update files)." ..
"\n\n**PROJECT UNDERSTANDING**: If the user asks about the project, use the project context provided above to give them detailed, accurate information about their codebase, architecture, and functionality. Respond conversationally, not with file commands." ..
"\n\n**FLUX.NVIM SPECIFIC**: When users ask about 'flux' or 'flux.nvim', they are asking about THIS specific Neovim plugin. Always refer to the project context to provide accurate information about the Flux.nvim plugin's features, architecture, and implementation." ..
"\n\nBe helpful, think out loud, and work with the user to solve problems together!"

  -- Debug: Log the prompt length to ensure it's not too long
  if #prompt > 10000 then
    vim.notify("Warning: Prompt is very long (" .. #prompt .. " chars)", vim.log.levels.WARN)
  end

  return prompt
end

-- Get current buffer context for chat
function M.get_current_buffer_context()
  -- If we have a pinned buffer, use that
  if state.state.pinned_buffer and api.nvim_buf_is_valid(state.state.pinned_buffer) then
    local lines = api.nvim_buf_get_lines(state.state.pinned_buffer, 0, -1, false)
    local filename = api.nvim_buf_get_name(state.state.pinned_buffer)
    local filetype = vim.bo[state.state.pinned_buffer].filetype
    
    -- Ensure we have valid data
    if filename and filename ~= "" then
      return {
        filename = filename,
        basename = vim.fn.fnamemodify(filename, ":t"),
        filetype = filetype or "",
        lines = lines or {},
        bufnr = state.state.pinned_buffer,
        is_pinned = true
      }
    end
  end
  
  -- Otherwise, get the current active buffer (dynamic)
  local current_buf = vim.fn.bufnr('#') ~= -1 and vim.fn.bufnr('#') or vim.fn.bufnr('%')
  if current_buf == state.state.chat_buf or current_buf == state.state.input_buf then
    -- Try to find the last code buffer
    for i = 1, vim.fn.bufnr('$') do
      if api.nvim_buf_is_valid(i) and vim.bo[i].buftype == "" then
        current_buf = i
        break
      end
    end
  end
  
  if api.nvim_buf_is_valid(current_buf) and vim.bo[current_buf].buftype == "" then
    local lines = api.nvim_buf_get_lines(current_buf, 0, -1, false)
    local filename = api.nvim_buf_get_name(current_buf)
    local filetype = vim.bo[current_buf].filetype
    
    -- Ensure we have valid data
    if filename and filename ~= "" then
      return {
        filename = filename,
        basename = vim.fn.fnamemodify(filename, ":t"),
        filetype = filetype or "",
        lines = lines or {},
        bufnr = current_buf,
        is_pinned = false
      }
    end
  end
  return nil
end

-- Get conversation history for context
function M.get_conversation_context()
  if #state.state.conversation_history == 0 then
    return ""
  end
  
  local context = "\n**Previous conversation context:**\n"
  for i, exchange in ipairs(state.state.conversation_history) do
    -- Include more context for recent conversations
    local user_preview = exchange.user:sub(1, 150)
    local assistant_preview = exchange.assistant:sub(1, 200)
    
    context = context .. string.format("Exchange %d:\n", i)
    context = context .. "Human: " .. user_preview .. "\n"
    context = context .. "Assistant: " .. assistant_preview .. "...\n\n"
  end
  
  context = context .. "**Remember**: Build on this conversation history and maintain continuity in our discussion."
  
  return context
end

-- Add to conversation history
function M.add_to_history(user_message, assistant_response)
  table.insert(state.state.conversation_history, {
    user = user_message,
    assistant = assistant_response
  })
  
  -- Keep only last 10 exchanges to prevent memory bloat
  if #state.state.conversation_history > 10 then
    table.remove(state.state.conversation_history, 1)
  end
end

-- Handle complex reasoning tasks
function M.handle_complex_reasoning(message)
  -- Add user message to chat
  require("chat.ui").add_to_chat("**You:** " .. message)
  require("chat.ui").add_to_chat("")
  
  -- Create a reasoning-focused prompt
  local reasoning_prompt = M.build_enhanced_prompt(message)
  reasoning_prompt = reasoning_prompt .. "\n\n**Reasoning Instructions:**\n" ..
    "1. Think through this step-by-step\n" ..
    "2. Break down complex problems into smaller parts\n" ..
    "3. Consider multiple approaches and their trade-offs\n" ..
    "4. Ask clarifying questions if needed\n" ..
    "5. Explain your reasoning process\n" ..
    "6. Suggest next steps or alternatives\n" ..
    "7. Be conversational and collaborative\n\n" ..
    "Let's work through this together!"
  
  require("chat.ui").add_to_chat("**LLM:** *thinking through this step-by-step...*")
  
  -- Start progress indicator
  local handle = require("ui.progress").start_chat("Processing complex reasoning task...")
  
  -- Send to LLM with reasoning prompt
  local providers = require("providers")
  local provider = providers.get_provider()
  provider:stream(reasoning_prompt,
    function(chunk) 
      require("ui.progress").complete(handle, "Reasoning...") 
      require("chat.streaming").update_chat_stream(chunk) 
    end,
    function(success, reason) 
      if success then
        require("chat.ui").add_to_chat("\n\n---")
        state.state.is_streaming = false
      else
        require("chat.streaming").update_chat_stream("\n\n**Error:** " .. reason)
      end
    end
  )
end

-- Handle complex file requests (read, update, multi-file operations)
function M.handle_complex_file_request(message)
  -- Add user message to chat
  require("chat.ui").add_to_chat("**You:** " .. message)
  require("chat.ui").add_to_chat("")
  
  -- Extract file names from the message
  local files = {}
  for filename in message:gmatch("([%w_%-%.]+%.%w+)") do
    table.insert(files, filename)
  end
  
  -- If no files found, try to parse differently
  if #files == 0 then
    require("chat.ui").add_to_chat("**System:** Could not identify specific files in your request.")
    require("chat.ui").add_to_chat("")
    -- Fall back to regular processing
    M.process_regular_message(message)
    return
  end
  
  -- Create enhanced prompt that includes file operations
  local enhanced_prompt = M.build_enhanced_prompt(message)
  
  -- Add file reading instructions for multiple files
  if #files > 0 then
    enhanced_prompt = enhanced_prompt .. "\n\nTo complete this request:\n"
    for _, file in ipairs(files) do
      enhanced_prompt = enhanced_prompt .. "- Use @READ " .. file .. " to read " .. file .. "\n"
    end
    enhanced_prompt = enhanced_prompt .. "- Use @UPDATE filename to overwrite/update existing files\n"
    enhanced_prompt = enhanced_prompt .. "- Use @CREATE filename to create new files\n"
    enhanced_prompt = enhanced_prompt .. "- Use @EDIT to modify the current buffer\n\n"
    enhanced_prompt = enhanced_prompt .. "IMPORTANT: Actually use these commands in your response to perform the file operations.\n"
  end
  
  require("chat.ui").add_to_chat("**LLM:** *processing file request...*")
  
  -- Start progress indicator
  local handle = require("ui.progress").start_chat("Processing multi-file request...")
  
  -- Send to LLM with enhanced prompt
  local providers = require("providers")
  local provider = providers.get_provider()
  provider:generate(enhanced_prompt, function(response, err)
    if err or not response then
      require("ui.progress").error(handle, "No response received: " .. (err or ""))
    else
      require("ui.progress").complete(handle, "Response received")
    end
    
    -- Process response for special commands
    require("chat.streaming").process_llm_response(response, message)
  end)
end

return M
