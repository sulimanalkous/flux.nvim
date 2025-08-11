
 # Flux.nvim - Development Documentation

 > **For Claude Code Assistance** - This file explains the Flux.nvim plugin architecture and recent fixes for quick context in new
 chat sessions.

 ## 🎯 **What is Flux.nvim?**

 Flux.nvim is a **custom-built AI coding partner and thinking agent** created as an alternative to complex existing solutions like
 Avante.nvim and CodeCompanion.nvim. Built from scratch with **~500 lines of clean Lua code** vs thousands in alternatives.

 ### **Core Philosophy**
 - 🧠 **Thinking Partner** - AI that reasons, plans, and works with you like a helpful colleague
 - ⚡  **Performance First** - Non-blocking async operations
 - 🎯 **Context-Aware & Proactive** - Aims to be a "thinking partner" with project-wide understanding.
 - 🔧 **Direct Control** - Simple, understandable codebase
 - 🚀 **Just Works** - Minimal configuration, but now fully configurable.

 ---

 ## 🏗️**Architecture Overview**

  lua/flux.nvim/
  ├── lua/
  │   ├── flux.lua              # Main entry point, configuration & keymaps
  │   ├── chat.lua              # Chat interface with file operations (CORE)
  │   ├── completion.lua        # Copilot-style code completion
  │   ├── edit.lua              # Interactive editing with diff preview
  │   ├── simple-llm.lua        # Core LLM communication & setup
  │   ├── embedding.lua         # Project indexing and embedding management (NEW!)
  │   ├── ui/
  │   │   ├── progress.lua      # Progress indicators (fidget.nvim integration)
  │   │   ├── diff.lua          # Visual diff interface for code changes
  │   │   └── error_handler.lua # Error handling & health monitoring
  │   └── utils.lua             # Common utility functions (NEW!)
  ├── plugin/
  │   └── flux.lua              # Plugin initialization & user commands (simplified)
  ├── README.md                 # Public documentation
  └── flux.md                   # This file - development context



 ---

 ## 💡 **Key Features & Components**

 ### 1. **Smart Chat Interface** (`chat.lua`)
 - **Context History** - Remembers last 10 conversations automatically
 - **Streaming Responses** - Real-time token-by-token display for a responsive feel. (NEW!)
 - **File Operations** - AI can read, create, update files via special commands:
   - `@READ filename` - Read any file/directory
   - `@CREATE filename` - Create new files
   - `@UPDATE filename` - Update/overwrite existing files (NEW!)
   - `@EDIT` - Edit current buffer with diff interface
   - `@LIST directory/` - List directory contents
 - **Buffer References** - `#{buffer}` to reference current/pinned files
 - **Command System** - `/help`, `/clear`, `/buffer` for chat management

 ### 2. **Code Completion** (`completion.lua`)
 - **Copilot-style** virtual text suggestions
 - **Smart Integration** - Works with nvim-cmp priority system
 - **Performance Optimized** - 2-second debounce, async operations
 - **Tab Acceptance** - Integrated with existing Tab workflows

 ### 3. **Interactive Editing** (`edit.lua`)
 - **Visual diff interface** - Shows before/after changes
 - **Accept/Reject workflow** - `ct` (accept), `co` (reject), `ca` (accept all)
 - **Floating hints** - Visual guides for diff actions

 ### 4. **LLM Integration** (`simple-llm.lua`)
 - **Configurable llama-server** - Host and port are now configurable. (NEW!)
 - **Dual Model Support** - Ready for generator and embedding models. (NEW!)
 - **Robust Requests** - Automatic retry logic for transient network issues. (NEW!)
 - **Direct llama-server** integration (localhost:1234)
 - **Model detection** - Auto-detects Qwen, DeepSeek, etc.
 - **Async operations** - Non-blocking with vim.fn.jobstart
 - **Error handling** - Graceful failures with user feedback, with health monitoring. (IMPROVED!)

 ### 5. **Project-Wide Context (RAG)** (`embedding.lua`) - NEW!
 - **Intelligent Context Retrieval** - AI can find and use relevant code snippets from your entire project.
 - **Embedding Model Integration** - Uses a dedicated embedding model to understand code semantics.
 - **Project Indexing** - `:FluxIndexProject` command to build a local knowledge base of your codebase.
 - **Context Augmentation** - Automatically injects relevant code into LLM prompts for smarter responses.

 ---
 
  ## 🎮 **Keymaps & Usage**
 
  ### **Chat Interface**
  - `<leader>aa` - Open chat interface
  - `<leader>ac` - Toggle chat interface
  - `Ctrl+S` - Send message (in chat input)
  - `q` - Close chat (in chat window)
 
  ### **Code Operations**
  - `<leader>ae` - Edit selection with AI (visual mode)
  - `<leader>af` - Edit entire buffer with AI
  - `<leader>lf` - Quick fix code with AI
  - `<leader>le` - Explain selection (visual mode)
  - `<leader>lp` - Ask AI a quick prompt
 
  ### **Completion**
  - `Tab` - Accept AI completion (highest priority in cmp chain)
  - `Ctrl+Space` - Trigger completion manually
  - `<leader>tc` - Toggle completion on/off
 
  ### **Project Indexing** - NEW!
  - `:FluxIndexProject` - Generates embeddings for your project files.
 
  ### **Chat Commands**
  - `/help` - Show help and commands
  - `/clear` - Clear conversation history
  - `/buffer` - Pin specific buffer for `#{buffer}` reference
 
  ---
 
  ## 🔧 **Recent Fixes & Issues Resolved**
 
  ### **Fixed Issues (Latest Session):**
 
  1.  **`<leader>aa` Keymap Conflict** ✅
      -   **Problem**: First press opened completion instead of chat
      -   **Solution**: Changed completion toggle from `<leader>cc` to `<leader>tc`
      -   **Files**: `completion.lua:347`, `flux.lua:23`
 
  2.  **Tab Completion Integration** ✅
      -   **Problem**: Tab conflicts between Flux, nvim-cmp, supermaven
      -   **Solution**: Integrated Flux into nvim-cmp Tab handler with priority system
      -   **Files**: `nvim-cmp.lua:39-48`, removed conflicting Tab keymap from `completion.lua`
 
  3.  **AI Not Responding to Complex Requests** ✅
      -   **Problem**: "read main.py and update flux.md" wasn't parsed correctly
      -   **Solutions**:
          -   Enhanced pattern matching for multi-file operations
          -   Added `@UPDATE` command for existing file overwrites
          -   Created `handle_complex_file_request()` function
          -   Improved AI prompting with clear command instructions
      -   **Files**: `chat.lua:212-220, 335-386, 570-598, 772-809`
 
  4.  **Response Window Focus Issue** ✅
      -   **Problem**: AI responses appeared in input window instead of chat
      -   **Solution**: Enhanced focus management and window switching
      -   **Files**: `chat.lua:1000-1021`, improved `scroll_to_bottom()` and `add_to_chat()`
 
  5.  **Plugin Loading & Circular Dependency** ✅
      -   **Problem**: `could not require('flux')` error during plugin loading.
      -   **Solution**: Refactored plugin loading to use `lazy.nvim`'s `config` function as the primary entry point. Resolved
  circular dependencies by lazy-loading `config` in `simple-llm.lua`, `completion.lua`, and `ui/error_handler.lua`. Renamed
  `init.lua` to `flux.lua` for better convention.
      -   **Files**: `plugin/flux.lua`, `lua/flux.lua` (formerly `init.lua`), `lua/simple-llm.lua`, `lua/completion.lua`,
  `lua/ui/error_handler.lua`.
 
  6.  **LLM Outputting Commands & `vim.NIL`** ✅
      -   **Problem**: LLM outputted `@EDIT` or `@READ` commands and `vim.NIL` in general conversation.
      -   **Solution**: Refined system prompt to explicitly instruct LLM to only output commands when performing file operations.
  Ensured `chunk_info.text` is never `nil` during embedding retrieval.
      -   **Files**: `lua/chat.lua`, `lua/embedding.lua`.
 
  ---
 
  ## 🚀 **How It Works - Technical Flow**
 
  ### **Chat Message Processing Flow:**
  1.  User types in input buffer → `send_message()`
  2.  **Pattern Matching**:
      -   `#{buffer}` → `handle_buffer_reference()`
      -   Complex file ops → `handle_complex_file_request()`
      -   Simple reads → `handle_file_read()`
      -   Regular chat → `process_regular_message()`
  3.  **RAG Context Augmentation (for regular chat):** (NEW!)
      -   User query is embedded using the embedding model.
      -   Relevant code chunks are retrieved from the project index.
      -   These chunks are prepended to the LLM prompt.
  4.  **Enhanced Prompt Building** with context + history + capabilities
  5.  **Async LLM Request** via `simple-llm.ask_llama_stream()` (now streaming!)
  6.  **Streaming Response Processing:** Tokens are received and appended to chat buffer in real-time.
  7.  **Response Processing** for special commands (`@READ`, `@UPDATE`, etc.)
  8.  **UI Updates** with progress indicators and window focus management
 
  ### **File Operation Commands:**
  -   AI receives instructions about available commands in every prompt.
  -   AI responds with special syntax: `@READ filename`, `@UPDATE filename`, etc.
  -   Commands are parsed and executed by `process_llm_response()`.
  -   Results shown in chat with status indicators.
 
  ### **Project Indexing Flow:** (NEW!)
  1.  User runs `:FluxIndexProject`.
  2.  `embedding.lua` glob-searches project files based on configured patterns.
  3.  File contents are chunked.
  4.  Each chunk is sent to the embedding model (`simple-llm.ask_embedding`).
  5.  The resulting embeddings are stored locally in `flux_embeddings.json` mapped to their file paths.
 
  ---
 
  ## 🔗 **Integration Points**
 
  ### **With Existing Neovim Config:**
  -   **nvim-cmp**: Integrated Tab completion priority system
  -   **fidget.nvim**: Progress indicator integration (optional fallback)
  -   **treesitter**: Syntax highlighting in diff views
  -   **LSP**: Works alongside language servers
 
  ### **Plugin Loading:**
  -   **Lazy.nvim config**: `lua/plugins/flux.lua` (now handles primary setup via `config` function)
  -   **Dependencies**: plenary.nvim, fidget.nvim (optional)
 
  ---
 
  ## 🐛 **Common Issues & Debugging**
 
  ### **If AI Doesn't Respond:**
  1.  Check llama-server running on configured host/port.
  2.  Use `:FluxModel status` to check model detection.
  3.  Check `:messages` for errors.
  4.  Try `:FluxChat` command directly.
 
  ### **If Completion Not Working:**
  1.  Check `<leader>tc` to toggle completion.
  2.  Verify no Tab keymap conflicts.
  3.  Check model server response time.
 
  ### **If File Operations Fail:**
  1.  Verify file permissions and paths.
  2.  Check if files exist (use `@READ` to test).
  3.  Use absolute paths if relative paths fail.
 
  ### **If RAG Context is Missing/Incorrect:** (NEW!)
  1.  Ensure both generator and embedding `llama-server` instances are running.
  2.  Verify `project_root` is correctly set in your `lazy.nvim` config.
  3.  Run `:FluxIndexProject` to build/update the embeddings.
  4.  Check `flux_embeddings.json` file for content.
 
  ---
 
  ## 🎯 **Development Context**
 
  ### **Built Because:**
  -   Existing AI plugins (Avante, CodeCompanion) were too complex to configure.
  -   Needed direct control over LLM integration.
  -   Wanted fast, simple, reliable AI assistance.
  -   Required file operation capabilities.
  -   Aimed for a "thinking partner" AI with project-wide context.
 
  ### **Success Metrics:**
  -   **~500 lines** vs thousands in alternatives (still relatively lean despite new features).
  -   **Direct llama-server** integration (no API keys).
  -   **Working in hours** vs days of configuration.
  -   **Exact features needed** - no bloat.
  -   **Project-wide context** via RAG.
  -   **Streaming responses** for better UX.
  -   **Robust error handling** and configurable setup.
 
  ### **Plugin Philosophy:**
  -   If you can't understand it, you can't fix it.
  -   Direct is better than abstracted.
  -   Performance over features.
  -   Simplicity over complexity.
 
  ---
 
  **Last Updated**: Session where we implemented RAG, streaming responses, improved robustness, and resolved plugin
  loading/circular dependency issues.
 
  **Status**: ✅  All major features implemented, plugin significantly enhanced.
