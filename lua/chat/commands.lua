local M = {}
local api = vim.api

-- Chat state (shared across modules)
local state = require("chat.state")

function M.setup()
  -- Will be implemented during migration
end

-- Show help in chat
function M.show_help()
  -- Add user message to chat
  require("chat.ui").add_to_chat("**You:** help")
  require("chat.ui").add_to_chat("")
  
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

  require("chat.ui").add_to_chat("**System:** " .. help_content)
  require("chat.ui").add_to_chat("")
  require("chat.ui").add_to_chat("---")
  require("chat.ui").add_to_chat("")
  -- Add input prompt for next message
  require("chat.input").add_input_prompt()
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
    require("chat.ui").add_to_chat("**System:** No buffers available to pin.")
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
      state.state.pinned_buffer = nil
      require("chat.ui").add_to_chat("**System:** Buffer unpinned. #{buffer} will now reference the current active file.")
    else
      -- Pin selected buffer
      local selected_buf = buffers[idx - 1] -- -1 because we added unpin option at index 1
              state.state.pinned_buffer = selected_buf.bufnr
      require("chat.ui").add_to_chat("**System:** Buffer pinned: **" .. selected_buf.basename .. "**")
      require("chat.ui").add_to_chat("**System:** #{buffer} will now always reference <buffer>" .. selected_buf.basename .. "</buffer>")
    end
    -- Add input prompt for next message
    require("chat.ui").add_to_chat("")
    require("chat.input").add_input_prompt()
  end)
end

-- Clear conversation history
function M.clear_history()
  state.state.conversation_history = {}
  vim.notify("Conversation history cleared", vim.log.levels.INFO)
end

return M
