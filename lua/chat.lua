-- Chat interface module for Flux.nvim
local M = {}

local api = vim.api
local fn = vim.fn

-- Import dependencies
local simple_llm = require("simple-llm")
local progress = require("ui.progress")
local diff_ui = require("ui.diff")
local embedding = require("embedding")

-- Chat state
M.state = {
  chat_buf = nil,
  input_buf = nil,
  pinned_buffer = nil,  -- Pinned buffer for #{buffer} reference
  conversation_history = {},  -- Store conversation for memory
  max_history = 10,  -- Keep last 10 exchanges
  is_streaming = false, -- To track if a response is currently streaming
}

-- Create the chat interface
function M.create_interface()
  -- If chat is already open, just focus on it
  if M.state.chat_buf and api.nvim_buf_is_valid(M.state.chat_buf) then
    local chat_win = vim.fn.bufwinnr(M.state.chat_buf)
    if chat_win > 0 and api.nvim_win_is_valid(chat_win) then
      api.nvim_set_current_win(chat_win)
      return
    end
  end

  -- Create main window split
  local width = math.floor(vim.o.columns * 0.4)
  
  -- Create single chat buffer for both chat and input
  M.state.chat_buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(M.state.chat_buf, "buftype", "nofile")
  api.nvim_buf_set_option(M.state.chat_buf, "filetype", "markdown")
  pcall(api.nvim_buf_set_name, M.state.chat_buf, "LLM_CHAT_" .. os.time())
  
  -- Use the same buffer for input (no separate input buffer)
  M.state.input_buf = M.state.chat_buf
  
  -- Open chat window on the right
  vim.cmd("vsplit")
  local win = api.nvim_get_current_win()
  api.nvim_win_set_buf(win, M.state.chat_buf)
  api.nvim_win_set_width(win, width)
  
  -- Set text wrapping options for chat window
  api.nvim_win_set_option(win, "wrap", true)
  api.nvim_win_set_option(win, "linebreak", true)
  api.nvim_win_set_option(win, "breakindent", true)
  api.nvim_win_set_option(win, "showbreak", "↳ ")
  
  -- Set initial content
  local welcome_lines = {
    "# 🤖 Flux.nvim - Your AI Coding Partner",
    "",
    "👋 **Hello! I'm your intelligent coding assistant and thinking partner.**",
    "",
    "**What I can do:**",
    "🧠 **Think & Reason** - I think step-by-step and explain my reasoning",
    "💬 **Natural Conversation** - Chat with me like a helpful colleague",
    "🔧 **Code Operations** - Edit, create, read files, and debug code",
    "📁 **Project Context** - I understand your entire codebase",
    "🎯 **Problem Solving** - Let's work together to solve complex problems",
    "",
    "**How to interact:**",
    "- Just talk to me naturally! Ask questions, discuss problems, or request help",
    "- \"What do you think about this code?\"",
    "- \"Help me debug this issue\"",
    "- \"Let's plan the architecture for this feature\"",
    "- \"Can you explain how this works?\"",
    "",
    "**Special Commands:**",
    "- `#{buffer}` - Reference current file content",
    "- `/help` - Show detailed help",
    "- `/clear` - Clear conversation history",
    "- `/buffer` - Pin a specific buffer",
    "",
    "**Controls:**",
    "- `Ctrl+S` - Send message", 
    "- `q` - Close chat (in chat window)",
    "",
    "Let's start coding together! 🚀",
    "",
    "---",
    "",
    "**Ask:** ",
  }
  api.nvim_buf_set_lines(M.state.chat_buf, 0, -1, false, welcome_lines)
  
  -- Set up keymaps for this buffer
  M.setup_keymaps()
  
  -- Focus on input area at the bottom
  vim.cmd("startinsert")
  api.nvim_win_set_cursor(win, {#welcome_lines, 7}) -- After "**Ask:** "
end

-- Set up keymaps for chat interface
function M.setup_keymaps()
  local opts = { buffer = M.state.input_buf, silent = true }
  
  -- Send message with Ctrl+S
  vim.keymap.set({"n", "i"}, "<C-s>", function()
    M.send_message()
  end, opts)
  
  -- Close chat
  vim.keymap.set("n", "q", function()
    M.close()
  end, { buffer = M.state.chat_buf, silent = true })
end

-- Get current buffer context for chat
function M.get_current_buffer_context()
  -- If we have a pinned buffer, use that
  if M.state.pinned_buffer and api.nvim_buf_is_valid(M.state.pinned_buffer) then
    local lines = api.nvim_buf_get_lines(M.state.pinned_buffer, 0, -1, false)
    local filename = api.nvim_buf_get_name(M.state.pinned_buffer)
    local filetype = vim.bo[M.state.pinned_buffer].filetype
    
    -- Ensure we have valid data
    if filename and filename ~= "" then
      return {
        filename = filename,
        basename = vim.fn.fnamemodify(filename, ":t"),
        filetype = filetype or "",
        lines = lines or {},
        bufnr = M.state.pinned_buffer,
        is_pinned = true
      }
    end
  end
  
  -- Otherwise, get the current active buffer (dynamic)
  local current_buf = vim.fn.bufnr('#') ~= -1 and vim.fn.bufnr('#') or vim.fn.bufnr('%')
  if current_buf == M.state.chat_buf or current_buf == M.state.input_buf then
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

-- Send message to LLM
function M.send_message()
  -- Get the last line (input line) from the chat buffer
  local all_lines = api.nvim_buf_get_lines(M.state.chat_buf, 0, -1, false)
  local last_line = all_lines[#all_lines] or ""
  local message = last_line:gsub("^%*%*Ask:%*%* ", ""):trim()

  if message == "" then
    vim.notify("Please enter a message", vim.log.levels.WARN)
    return
  end

  -- Remove the input line and add user message
  api.nvim_buf_set_lines(M.state.chat_buf, #all_lines - 1, #all_lines, false, {})
  M.add_to_chat("**You:** " .. message)
  M.add_to_chat("")

  -- Check for help command
  if message:lower():match("^/?help$") or message:lower():match("^/?commands$") then
    M.show_help()
    M.add_input_prompt()
    return
  end

  -- Check for /buffer command
  if message:lower():match("^/?buffer$") then
    M.show_buffer_picker()
    M.add_input_prompt()
    return
  end

  -- Check for /clear command
  if message:lower():match("^/?clear$") then
    M.clear_history()
    M.add_to_chat("**System:** Conversation history cleared. Fresh start!")
    M.add_to_chat("")
    M.add_to_chat("---")
    M.add_to_chat("")
    M.add_input_prompt()
    return
  end

  -- Check for #{buffer} reference
  if message:match("#{buffer}") then
    M.handle_buffer_reference(message)
    return
  end

  -- Check for complex reasoning tasks
  local lower_msg = message:lower()
  if lower_msg:match("think") or
     lower_msg:match("reason") or
     lower_msg:match("plan") or
     lower_msg:match("design") or
     lower_msg:match("architecture") or
     lower_msg:match("debug") or
     lower_msg:match("problem") or
     lower_msg:match("help me") or
     lower_msg:match("how should") or
     lower_msg:match("what do you think") or
     lower_msg:match("let's work") or
     lower_msg:match("step by step") then
    M.handle_complex_reasoning(message)
    return
  end

  -- Check for file operations (more comprehensive patterns)
  if lower_msg:match("read.*%.%w+") or -- read any file with extension
     lower_msg:match("read.*file") or    -- read ... file
     lower_msg:match("show.*%.%w+") or   -- show any file with extension
     lower_msg:match("read.*and.*update") or -- read X and update Y
     lower_msg:match("read.*update") then   -- read ... update
    M.handle_complex_file_request(message)
    return
  end

  -- Regular message processing
  M.process_regular_message(message)
end

-- Add input prompt to the end of the chat buffer
function M.add_input_prompt()
  M.add_to_chat("**Ask:** ")
  -- Move cursor to the input line
  local lines = api.nvim_buf_get_lines(M.state.chat_buf, 0, -1, false)
  api.nvim_win_set_cursor(api.nvim_get_current_win(), {#lines, 7}) -- After "**Ask:** "
  vim.cmd("startinsert")
end

-- Show buffer picker
function M.show_buffer_picker()
  -- Get list of valid buffers
  local buffers = {}
  for i = 1, vim.fn.bufnr('$') do
    if api.nvim_buf_is_valid(i) and vim.bo[i].buftype == "" then
      local filename = api.nvim_buf_get_name(i)
      if filename and filename ~= "" then
        local basename = vim.fn.fnamemodify(filename, ":t")
        table.insert(buffers, {
          bufnr = i,
          filename = filename,
          basename = basename,
          display = string.format("%d: %s", i, basename)
        })
      end
    end
  end
  
  if #buffers == 0 then
    M.add_to_chat("**System:** No buffers available to pin.")
    return
  end
  
  -- Create selection items
  local items = {}
  for _, buf in ipairs(buffers) do
    table.insert(items, buf.display)
  end
  
  -- Add unpin option
  table.insert(items, 1, "🔓 Unpin current buffer")
  
  -- Use vim.ui.select for buffer selection
  vim.ui.select(items, {
    prompt = "Select buffer to pin:",
    format_item = function(item)
      return item
    end
  }, function(choice, idx)
    if not choice then return end
    
    if idx == 1 then
      -- Unpin buffer
      M.state.pinned_buffer = nil
      M.add_to_chat("**System:** Buffer unpinned. #{buffer} will now reference the current active file.")
    else
      -- Pin selected buffer
      local selected_buf = buffers[idx - 1] -- -1 because we added unpin option at index 1
      M.state.pinned_buffer = selected_buf.bufnr
      M.add_to_chat("**System:** Buffer pinned: **" .. selected_buf.basename .. "**")
      M.add_to_chat("**System:** #{buffer} will now always reference <buffer>" .. selected_buf.basename .. "</buffer>")
    end
    -- Add input prompt for next message
    M.add_to_chat("")
    M.add_input_prompt()
  end)
end

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
    local enhanced_message = M.build_enhanced_prompt(message)
    
    -- Add buffer content to prompt
    enhanced_message = enhanced_message .. string.format([[

Referenced Buffer (%s%s):
```%s
%s
```]], context.is_pinned and "pinned: " or "current: ", context.basename, context.filetype, buffer_content)
    
    -- Add user message to chat (showing the substituted version)
    M.add_to_chat("**You:** " .. message)
    M.add_to_chat("")
    M.add_to_chat("**LLM:** *thinking...*")
    
    -- Start progress indicator
    local handle = progress.start_chat("Processing request with buffer context...")
    
    -- Send to LLM with buffer context
    simple_llm.ask_llama(enhanced_message, function(response, err)
      if err or not response then
        progress.error(handle, "No response received: " .. (err or ""))
      else
        progress.complete(handle, "Response received")
        -- Add buffer reference to the end (only if it's valid)
        if buffer_reference and buffer_reference ~= vim.NIL then
          response = response .. string.format("\n\n%s", buffer_reference)
        end
      end
      
      -- Process response for special commands
      M.process_llm_response(response, message)
    end)
  else
    M.add_to_chat("**You:** " .. message)
    M.add_to_chat("")
    M.add_to_chat("**System:** No buffer is currently open to reference.")
    M.add_to_chat("")
    M.add_input_prompt()
  end
end

-- Handle complex file requests (read, update, multi-file operations)
function M.handle_complex_file_request(message)
  -- Add user message to chat
  M.add_to_chat("**You:** " .. message)
  M.add_to_chat("")
  
  -- Extract file names from the message
  local files = {}
  for filename in message:gmatch("([%w_%-%.]+%.%w+)") do
    table.insert(files, filename)
  end
  
  -- If no files found, try to parse differently
  if #files == 0 then
    M.add_to_chat("**System:** Could not identify specific files in your request.")
    M.add_to_chat("")
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
  
  M.add_to_chat("**LLM:** *processing file request...*")
  
  -- Start progress indicator
  local handle = progress.start_chat("Processing multi-file request...")
  
  -- Send to LLM with enhanced prompt
  simple_llm.ask_llama(enhanced_prompt, function(response, err)
    if err or not response then
      progress.error(handle, "No response received: " .. (err or ""))
    else
      progress.complete(handle, "Response received")
    end
    
    -- Process response for special commands
    M.process_llm_response(response, message)
  end)
end

-- Handle simple file read requests (kept for compatibility)
function M.handle_file_read(message)
  -- Extract file name or default to TODO.md
  local filename = message:match("([%w_%-%.]+%.%w+)") or "TODO.md"
  
  -- Add user message to chat
  M.add_to_chat("**You:** " .. message)
  M.add_to_chat("")
  
  -- Read the file directly
  local read_result = M.handle_read_command(filename)
  M.add_to_chat("**[📖 Reading " .. filename .. "]**")
  M.add_to_chat(read_result)
  M.add_to_chat("")
  
  -- Add input prompt for next message
  M.add_to_chat("")
  M.add_input_prompt()
end

-- Process regular message
function M.process_regular_message(message)
  local handle = progress.start_chat("Processing request...", "chat_" .. os.time())

  M.add_to_chat("**LLM:** *thinking...*")

  local enhanced_message_base = M.build_enhanced_prompt(message)
  local full_response_chunks = {}
  M.state.is_streaming = false -- Reset streaming state

  -- Step 1: Get embedding for the user's query
  progress.update(handle, "Generating query embedding...")
  simple_llm.ask_embedding(message, function(query_embedding, err_embed)
    if err_embed or not query_embedding then
      vim.notify("Flux.nvim: Failed to get query embedding: " .. (err_embed or "Unknown error"), vim.log.levels.WARN)
      -- Fallback to non-augmented prompt if embedding fails
      local fallback_prompt = enhanced_message_base .. "\n\n**Note**: Project context unavailable due to embedding service issue. Please respond based on general knowledge and ask the user to run :FluxIndexProject if they need project-specific help."
      simple_llm.ask_llama_stream(fallback_prompt,
        function(chunk) 
          progress.complete(handle, "Receiving response...") 
          M.update_chat_stream(chunk) 
          table.insert(full_response_chunks, chunk) 
        end,
        function(success, reason) M.handle_stream_finish(success, reason, message, full_response_chunks) end
      )
      return
    end

    -- Step 2: Find relevant chunks from project index
    progress.update(handle, "Finding relevant context...")
    local relevant_chunks = embedding.find_relevant_chunks(query_embedding, 5) -- Get top 5 for better coverage

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
    progress.update(handle, "Sending augmented request to LLM...")
    simple_llm.ask_llama_stream(augmented_prompt,
      function(chunk) 
        progress.complete(handle, "Receiving response...") 
        M.update_chat_stream(chunk) 
        table.insert(full_response_chunks, chunk) 
      end,
      function(success, reason) M.handle_stream_finish(success, reason, message, full_response_chunks) end
    )
  end)
end

-- Helper function to handle stream finish (extracted for clarity)
function M.handle_stream_finish(success, reason, user_message, full_response_chunks)
  if not success then
    M.update_chat_stream("\n\n**Error:** " .. reason)
  end
  
  M.add_to_chat("\n\n---")
  M.add_to_chat("")
  M.state.is_streaming = false
  -- Save full response to history
  local full_response = table.concat(full_response_chunks, "")
  M.add_to_history(user_message, full_response)
  -- Add input prompt for next message
  M.add_input_prompt()
end

-- Build enhanced prompt with context and capabilities  
function M.build_enhanced_prompt(user_message)
  local context = M.get_current_buffer_context()
  
  -- Ensure context is valid
  if context and (not context.filename or context.filename == "" or context.filename == vim.NIL) then
    context = nil
  end
  
  local prompt = [[You are an intelligent AI coding assistant and thinking partner. You should act like a helpful colleague who can reason, plan, and work with the user to solve problems together.

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
"\n\nBe helpful, think out loud, and work with the user to solve problems together!"

  -- Debug: Log the prompt length to ensure it's not too long
  if #prompt > 10000 then
    vim.notify("Warning: Prompt is very long (" .. #prompt .. " chars)", vim.log.levels.WARN)
  end

  return prompt
end


-- Update analysis response (helper function)
function M.update_analysis_response(analysis, handle, err)
  -- Remove the "analyzing..." line
  local lines = api.nvim_buf_get_lines(M.state.chat_buf, 0, -1, false)
  for i = #lines, 1, -1 do
    if lines[i]:match("analyzing%.%.%.") then
      table.remove(lines, i)
      break
    end
  end
  
  if analysis and analysis:trim() ~= "" then
    progress.complete(handle, "Analysis complete")
    
    -- Add analysis
    local analysis_lines = vim.split("**LLM:** " .. analysis, "\n", { plain = true })
    for _, line in ipairs(analysis_lines) do
      table.insert(lines, line)
    end
  else
    progress.error(handle, "Analysis failed: " .. (err or ""))
    table.insert(lines, "**LLM:** I couldn't analyze the file content properly.")
  end
  
  table.insert(lines, "")
  table.insert(lines, "---")
  table.insert(lines, "")
  
  api.nvim_buf_set_lines(M.state.chat_buf, 0, -1, false, lines)
  
  -- Auto-scroll to bottom
  M.scroll_to_bottom()
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
      
      local update_result = M.handle_update_command(filename:trim(), file_content)
      processed_response = processed_response .. "\n**[📝 Updated file]** " .. update_result .. "\n\n"
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
      
      local create_result = M.handle_create_command(filename:trim(), file_content)
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
      
      local edit_result = M.handle_edit_command(code_content)
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
      local read_result = M.handle_read_command(path)
      processed_response = processed_response .. "\n**[📖 Reading " .. path .. "]**\n" .. read_result .. "\n\n"
      
      -- If user asked for understanding/analysis, send content back to AI
      if user_message and (user_message:lower():match("understand") or user_message:lower():match("analyze") or user_message:lower():match("tell me")) then
        -- Extract just the file content (remove markdown formatting)
        local file_content = read_result:gsub("```\n", ""):gsub("```", ""):trim()
        if file_content and #file_content > 0 then
          -- Send follow-up request to AI for analysis
          vim.defer_fn(function()
            local analysis_prompt = "Based on this file content, please analyze and explain what you understand:\n\n" .. file_content
            simple_llm.ask_llama(analysis_prompt, function(analysis)
              if analysis then
                M.add_to_chat("")
                M.add_to_chat("**Analysis:** " .. analysis)
                M.add_to_chat("")
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
      local list_result = M.handle_read_command(path)
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
  M.add_to_history(user_message or "", processed_response:trim())
  
  -- Add input prompt for next message
  M.add_to_chat("")
  M.add_input_prompt()
end

-- Handle @READ command
function M.handle_read_command(path)
  local handle = progress.start_read("Reading " .. path)
  path = path:trim()
  
  -- Handle special cases for current directory
  if path:match("current directory") or path:match("current folder") then
    path = "."
  end
  
  local full_path = vim.fn.expand(path)
  
  if vim.fn.isdirectory(full_path) == 1 then
    progress.update(handle, "Listing directory...")
    local files = vim.fn.glob(full_path .. "/*", false, true)
    if #files == 0 then
      progress.error(handle, "Directory empty")
      return "Directory is empty or doesn't exist: " .. path
    end
    
    local result = "📁 Files in **" .. path .. "**:\n"
    for _, file in ipairs(files) do
      local basename = vim.fn.fnamemodify(file, ":t")
      local is_dir = vim.fn.isdirectory(file) == 1
      result = result .. (is_dir and "📁 " or "📄 ") .. basename .. "\n"
    end
    progress.complete(handle, "Directory listed")
    return result
  end
  
  if vim.fn.filereadable(full_path) == 1 then
    progress.update(handle, "Loading file content...")
    local lines = vim.fn.readfile(full_path)
    local content = table.concat(lines, "\n")
    if #content > 2000 then
      content = content:sub(1, 2000) .. "\n... (file truncated - " .. #lines .. " total lines)"
      progress.complete(handle, "File loaded (truncated)")
    else
      progress.complete(handle, "File loaded")
    end
    return "```\n" .. content .. "\n```"
  else
    progress.error(handle, "File not found")
    return "❌ File not found or not readable: " .. path
  end
end

-- Handle @UPDATE command (update existing files)
function M.handle_update_command(filename, file_content)
  local handle = progress.start_edit("Updating file " .. filename)
  
  -- Clean up the content
  if file_content then
    file_content = file_content:trim()
  else
    file_content = ""
  end
  
  progress.update(handle, "Writing updated content...")
  
  -- Expand path (handle relative paths)
  local full_path = vim.fn.expand(filename)
  
  -- Write file (overwrite if exists)
  local lines = vim.split(file_content, "\n")
  local success = pcall(vim.fn.writefile, lines, full_path)
  
  if success then
    progress.complete(handle, "File updated successfully")
    
    -- Try to open the file in a buffer if it's not already open
    local existing_buf = vim.fn.bufnr(full_path)
    if existing_buf == -1 then
      vim.cmd("edit " .. vim.fn.fnameescape(full_path))
    else
      -- Reload the buffer to show changes
      vim.cmd("checktime")
    end
    
    return "✅ **File updated successfully**: " .. filename .. " (" .. #lines .. " lines)"
  else
    progress.error(handle, "Failed to update file")
    return "❌ Failed to update file: " .. filename
  end
end

-- Handle @CREATE command
function M.handle_create_command(filename, file_content)
  local handle = progress.start_edit("Creating file " .. filename)
  
  -- Clean up the content
  if file_content then
    file_content = file_content:trim()
  else
    file_content = ""
  end
  
  progress.update(handle, "Writing file content...")
  
  -- Expand path (handle relative paths)
  local full_path = vim.fn.expand(filename)
  
  -- Check if file already exists
  if vim.fn.filereadable(full_path) == 1 then
    progress.error(handle, "File already exists")
    return "❌ File already exists: " .. filename .. ". Use @EDIT to modify existing files."
  end
  
  -- Create directory if it doesn't exist
  local dir = vim.fn.fnamemodify(full_path, ":h")
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end
  
  -- Write file
  local lines = vim.split(file_content, "\n")
  local success = pcall(vim.fn.writefile, lines, full_path)
  
  if success then
    progress.complete(handle, "File created successfully")
    
    -- Open the file in a new buffer
    vim.cmd("edit " .. vim.fn.fnameescape(full_path))
    
    return "✅ **File created successfully**: " .. filename .. " (" .. #lines .. " lines)"
  else
    progress.error(handle, "Failed to create file")
    return "❌ Failed to create file: " .. filename
  end
end

-- Handle @EDIT command
function M.handle_edit_command(new_content)
  local handle = progress.start_edit("Preparing edit diff")
  local context = M.get_current_buffer_context()
  if not context then
    progress.error(handle, "No file open")
    return "❌ No file open to edit"
  end
  
  new_content = new_content:trim()
  if new_content == "" then
    progress.error(handle, "No content provided")
    return "❌ No content provided for editing"
  end
  
  progress.update(handle, "Showing diff interface...")
  
  -- Show diff interface instead of directly applying changes
  local success = diff_ui.show_edit_diff(context.bufnr, new_content, "Chat Edit: " .. context.basename)
  
  if success then
    progress.complete(handle, "Diff interface opened")
    return "✅ **Diff interface opened** for **" .. context.basename .. "** - Review changes and accept/reject"
  else
    progress.error(handle, "Failed to open diff")
    return "❌ Failed to open diff interface"
  end
end

-- Update chat with a streaming response chunk
function M.update_chat_stream(chunk)
  if not M.state.chat_buf or not api.nvim_buf_is_valid(M.state.chat_buf) then return end

  -- Filter out vim.NIL chunks
  if not chunk or chunk == vim.NIL or tostring(chunk) == "vim.NIL" then
    return
  end

  local lines = api.nvim_buf_get_lines(M.state.chat_buf, 0, -1, false)
  
  if M.state.is_streaming == false then
    -- First chunk, replace "thinking..."
    M.state.is_streaming = true
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

  api.nvim_buf_set_lines(M.state.chat_buf, 0, -1, false, lines)
  M.scroll_to_bottom()
end

-- Update chat with final response
function M.update_chat_response_full(response)

  -- Validate chat buffer exists and is valid
  if not M.state.chat_buf or not api.nvim_buf_is_valid(M.state.chat_buf) then
    vim.notify("Chat buffer is invalid, cannot update response", vim.log.levels.ERROR)
    return
  end
  
  local lines = api.nvim_buf_get_lines(M.state.chat_buf, 0, -1, false)
  
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

  api.nvim_buf_set_lines(M.state.chat_buf, 0, -1, false, lines)

  -- Auto-scroll to bottom
  M.scroll_to_bottom()
end

-- Show help in chat
function M.show_help()
  -- Add user message to chat
  M.add_to_chat("**You:** help")
  M.add_to_chat("")
  
  local help_content = [[**🤖 Flux.nvim - Your AI Coding Partner**

👋 **I'm your intelligent coding assistant and thinking partner!**

🧠 **My Personality:**
- I think step-by-step and explain my reasoning
- I ask clarifying questions when needed
- I'm conversational and natural, like talking to a friend
- I show enthusiasm for solving problems together
- I admit when I'm unsure and suggest alternatives
- I build on our previous conversations
- I'm proactive in suggesting improvements

🔧 **Available Keybindings:**
- `<leader>aa` - Open/create chat interface
- `<leader>ac` - Toggle chat interface 
- `<leader>ae` - Edit selected code (visual mode)
- `<leader>af` - Edit entire buffer
- `<leader>lf` - Fix code with AI
- `<leader>le` - Explain selected code (visual mode)
- `<leader>lp` - Ask AI a quick prompt
- `<leader>ls` - Check llama-server status
- `<leader>tc` - Toggle code completion

💬 **Chat Commands:**
- `help` or `/help` - Show this help
- `buffer` or `/buffer` - Pin a specific buffer for #{buffer} reference
- `clear` or `/clear` - Clear conversation history (fresh start)

🎯 **How to Interact with Me:**
**Just talk naturally!** I understand context and can:
- **Think through problems** step-by-step with you
- **Debug issues** by analyzing code and reasoning
- **Plan architecture** and discuss design decisions
- **Review code** and suggest improvements
- **Explain concepts** in detail
- **Work on complex tasks** together

**Example conversations:**
- "What do you think about this code structure?"
- "Help me debug this issue - I'm getting an error when..."
- "Let's plan the architecture for this new feature"
- "Can you explain how this algorithm works?"
- "I'm stuck on this problem, can you help me think through it?"

🤖 **My Capabilities:**
- **Deep reasoning** about code and software problems
- **Project-wide context** awareness
- **File operations** (read, edit, create, list)
- **Code review** and improvement suggestions
- **Debugging** and problem-solving
- **Planning** and architecture discussions
- **Natural conversation** about any coding topic

🎮 **Chat Controls:**
- `Ctrl+S` - Send message
- `q` - Close chat (when in chat window)
- Type naturally - I understand context

📁 **File Operations:**
I automatically detect when you want to:
- Read files/directories (just ask to read them)
- Edit current file (I show diff for approval)
- List directory contents (ask about files in folders)
- Create new files or update existing ones

⚡ **Memory & Context:**
- **Session Memory**: I remember our last 10 conversations
- **Current File**: I see your active/pinned file
- **Project Context**: I understand your entire codebase
- **Conversation Continuity**: I build on our previous discussions

🔗 **Buffer Reference:**
- Use `#{buffer}` to reference file content
- **Dynamic mode**: #{buffer} references currently active file
- **Pinned mode**: Use `/buffer` to pin a specific file
- Example: "#{buffer} - what do you think about this code?"

🚀 **Let's code together!** I'm here to think, reason, and solve problems with you.
- Shows as <buffer>🔄filename</buffer> (dynamic) or <buffer>📌filename</buffer> (pinned)]]

  M.add_to_chat("**System:** " .. help_content)
  M.add_to_chat("")
  M.add_to_chat("---")
  M.add_to_chat("")
  -- Add input prompt for next message
  M.add_input_prompt()
end

-- Scroll chat window to bottom
function M.scroll_to_bottom()
  local chat_win = fn.bufwinnr(M.state.chat_buf)
  if chat_win ~= -1 and api.nvim_win_is_valid(chat_win) then
    local lines = api.nvim_buf_get_lines(M.state.chat_buf, 0, -1, false)
    pcall(api.nvim_win_set_cursor, chat_win, {#lines, 0})
    
    -- Force redraw and make sure the chat window is visible
    pcall(api.nvim_set_current_win, chat_win)
    vim.cmd("redraw!")
    
    -- Keep focus in chat window for a moment so user sees the response
    vim.defer_fn(function()
      -- Focus back to input window for next message
      local input_win = fn.bufwinnr(M.state.input_buf)
      if input_win ~= -1 and api.nvim_win_is_valid(input_win) then
        pcall(api.nvim_set_current_win, input_win)
        -- Position cursor after "Ask: " prompt
        pcall(api.nvim_win_set_cursor, input_win, {1, 5})
      end
    end, 500) -- Give user 500ms to see the response
  end
end

-- Add text to chat buffer
function M.add_to_chat(text)
  -- Validate chat buffer exists and is valid
  if not M.state.chat_buf or not api.nvim_buf_is_valid(M.state.chat_buf) then
    vim.notify("Chat buffer is invalid, cannot add text", vim.log.levels.ERROR)
    return
  end
  
  -- Debug: Check buffer info
  local chat_buf_name = api.nvim_buf_get_name(M.state.chat_buf)
  local input_buf_name = M.state.input_buf and api.nvim_buf_is_valid(M.state.input_buf) and api.nvim_buf_get_name(M.state.input_buf) or "invalid"
  
  -- Debug output (can be commented out later)
  -- vim.notify(string.format("Adding to chat - Chat buf: %s, Input buf: %s", chat_buf_name, input_buf_name), vim.log.levels.DEBUG)
  
  local lines = api.nvim_buf_get_lines(M.state.chat_buf, 0, -1, false)
  
  -- Split text by newlines and add each line separately
  local text_lines = vim.split(text, "\n", { plain = true })
  for _, line in ipairs(text_lines) do
    table.insert(lines, line)
  end
  
  -- Force update the chat buffer specifically
  local success = pcall(api.nvim_buf_set_lines, M.state.chat_buf, 0, -1, false, lines)
  if not success then
    vim.notify("Failed to update chat buffer", vim.log.levels.ERROR)
    return
  end
  
  -- Auto-scroll to bottom
  M.scroll_to_bottom()
end

-- Add to conversation history
function M.add_to_history(user_message, ai_response)
  table.insert(M.state.conversation_history, {
    user = user_message,
    assistant = ai_response,
    timestamp = os.time()
  })
  
  -- Keep only the last max_history exchanges
  while #M.state.conversation_history > M.state.max_history do
    table.remove(M.state.conversation_history, 1)
  end
end

-- Get conversation history for context
function M.get_conversation_context()
  if #M.state.conversation_history == 0 then
    return ""
  end
  
  local context = "\n**Previous conversation context:**\n"
  for i, exchange in ipairs(M.state.conversation_history) do
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

-- Clear conversation history
function M.clear_history()
  M.state.conversation_history = {}
  vim.notify("Conversation history cleared", vim.log.levels.INFO)
end

-- Close chat interface
function M.close()
  if M.state.chat_buf then
    pcall(api.nvim_buf_delete, M.state.chat_buf, { force = true })
  end
  if M.state.input_buf then
    pcall(api.nvim_buf_delete, M.state.input_buf, { force = true })
  end
  -- Keep conversation history when closing chat (persist in session)
  M.state.chat_buf = nil
  M.state.input_buf = nil
end

-- Toggle chat interface
function M.toggle()
  if M.state.chat_buf and api.nvim_buf_is_valid(M.state.chat_buf) then
    M.close()
  else
    M.create_interface()
  end
end

-- Add string trim function if not available
if not string.trim then
  function string.trim(s)
    return s:match("^%s*(.-)%s*$")
  end
end

-- Agent-like reasoning function for complex tasks
function M.handle_complex_reasoning(message)
  -- Add user message to chat
  M.add_to_chat("**You:** " .. message)
  M.add_to_chat("")
  
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
  
  M.add_to_chat("**LLM:** *thinking through this step-by-step...*")
  
  -- Start progress indicator
  local handle = progress.start_chat("Processing complex reasoning task...")
  
  -- Send to LLM with reasoning prompt
  simple_llm.ask_llama_stream(reasoning_prompt,
    function(chunk) 
      progress.complete(handle, "Reasoning...") 
      M.update_chat_stream(chunk) 
    end,
    function(success, reason) 
      if success then
        M.add_to_chat("\n\n---")
        M.add_to_chat("")
        M.state.is_streaming = false
        -- Add input prompt for next message
        M.add_input_prompt()
      else
        M.update_chat_stream("\n\n**Error:** " .. reason)
        M.add_to_chat("")
        M.add_input_prompt()
      end
    end
  )
end

return M
