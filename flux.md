
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
  │   ├── chat/                 # Chat interface modules (REFACTORED!)
  │   │   ├── init.lua          # Chat module entry point
  │   │   ├── state.lua         # Shared chat state management
  │   │   ├── ui.lua            # Window management and UI creation
  │   │   ├── input.lua         # User input handling
  │   │   ├── messages.lua      # Message processing and RAG
  │   │   ├── streaming.lua     # LLM response streaming
  │   │   ├── commands.lua      # Chat commands (/help, /clear, etc.)
  │   │   └── markdown.lua      # Markdown rendering (placeholder)
  │   ├── providers/            # LLM provider abstraction (NEW!)
  │   │   ├── init.lua          # Provider registry and management
  │   │   ├── base.lua          # Abstract provider interface
  │   │   └── llama_cpp.lua     # llama.cpp provider implementation
  │   ├── tools/                # Utility tools (NEW!)
  │   │   ├── init.lua          # Tool registry and management
  │   │   ├── file_ops.lua      # File operations (@READ, @CREATE, etc.)
  │   │   ├── buffer_ref.lua    # Buffer reference handling
  │   │   └── project_index.lua # RAG and project indexing
  │   ├── ui/                   # UI components
  │   │   ├── progress.lua      # Progress indicators (fidget.nvim integration)
  │   │   ├── diff.lua          # Visual diff interface for code changes
  │   │   └── error_handler.lua # Error handling & health monitoring
  │   ├── completion.lua        # Copilot-style code completion
  │   ├── edit.lua              # Interactive editing with diff preview
  │   ├── simple-llm.lua        # Legacy LLM communication (deprecated)
  │   ├── embedding.lua         # Legacy embedding (deprecated)
  │   └── utils.lua             # Common utility functions
  ├── plugin/
  │   └── flux.lua              # Plugin initialization & user commands
  ├── README.md                 # Public documentation
  └── flux.md                   # This file - development context



 ---

 ## 💡 **Key Features & Components**

 ### 1. **Smart Chat Interface** (`chat/` modules) - REFACTORED!
 - **Modular Architecture** - Split into focused modules for better maintainability
 - **Context History** - Remembers last 10 conversations automatically
 - **Streaming Responses** - Real-time token-by-token display for a responsive feel
 - **Proper UI Layout** - 20% input window (bottom), 80% result window (top)
 - **File Operations** - AI can read, create, update files via special commands:
   - `@READ filename` - Read any file/directory
   - `@CREATE filename` - Create new files
   - `@UPDATE filename` - Update/overwrite existing files
   - `@EDIT` - Edit current buffer with diff interface
   - `@LIST directory/` - List directory contents
 - **Buffer References** - `#{buffer}` to reference current/pinned files
 - **Command System** - `/help`, `/clear`, `/buffer` for chat management
 - **Robust State Management** - Prevents multiple responses and handles errors gracefully

 ### 2. **Code Completion** (`completion.lua`)
 - **Copilot-style** virtual text suggestions
 - **Smart Integration** - Works with nvim-cmp priority system
 - **Performance Optimized** - 2-second debounce, async operations
 - **Tab Acceptance** - Integrated with existing Tab workflows

 ### 3. **Interactive Editing** (`edit.lua`)
 - **Visual diff interface** - Shows before/after changes
 - **Accept/Reject workflow** - `ct` (accept), `co` (reject), `ca` (accept all)
 - **Floating hints** - Visual guides for diff actions

 ### 4. **LLM Integration** (`providers/` modules) - REFACTORED!
 - **Provider Abstraction** - Clean interface for different LLM providers (llama.cpp, Ollama ready)
 - **Configurable llama-server** - Host and port are now configurable
 - **Dual Model Support** - Ready for generator and embedding models
 - **Robust Requests** - Automatic retry logic for transient network issues
 - **Direct llama-server** integration (localhost:1234)
 - **Model detection** - Auto-detects Qwen, DeepSeek, etc.
 - **Async operations** - Non-blocking with vim.fn.jobstart
 - **Error handling** - Graceful failures with user feedback, with health monitoring
 - **Extensible** - Easy to add new providers (Ollama support planned)

 ### 5. **Project-Wide Context (RAG)** (`tools/project_index.lua`) - REFACTORED!
 - **Intelligent Context Retrieval** - AI can find and use relevant code snippets from your entire project
 - **Embedding Model Integration** - Uses a dedicated embedding model to understand code semantics
 - **Project Indexing** - `:FluxIndexProject` command to build a local knowledge base of your codebase
 - **Context Augmentation** - Automatically injects relevant code into LLM prompts for smarter responses
 - **Modular Design** - Separated from chat logic for better maintainability

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

 ### **Major Refactoring (Latest Session):**

 1.  **Complete Architecture Refactoring** ✅
     -   **Problem**: Monolithic `chat.lua` (1339 lines) was hard to debug and maintain
     -   **Solution**: Split into modular architecture with focused responsibilities:
         -   `chat/state.lua` - Shared state management
         -   `chat/ui.lua` - Window management and UI creation
         -   `chat/input.lua` - User input handling
         -   `chat/messages.lua` - Message processing and RAG
         -   `chat/streaming.lua` - LLM response streaming
         -   `chat/commands.lua` - Chat commands
         -   `chat/markdown.lua` - Markdown rendering (placeholder)
     -   **Benefits**: Better maintainability, easier debugging, cleaner code organization

 2.  **Provider Abstraction System** ✅
     -   **Problem**: Hard-coded llama.cpp integration, difficult to add new providers
     -   **Solution**: Created provider abstraction with:
         -   `providers/base.lua` - Abstract provider interface
         -   `providers/llama_cpp.lua` - llama.cpp implementation
         -   `providers/init.lua` - Provider registry and management
     -   **Benefits**: Easy to add Ollama and other providers, cleaner separation of concerns

 3.  **Tools Modularization** ✅
     -   **Problem**: File operations and RAG logic mixed with chat logic
     -   **Solution**: Separated into focused tool modules:
         -   `tools/file_ops.lua` - File operations (@READ, @CREATE, etc.)
         -   `tools/buffer_ref.lua` - Buffer reference handling
         -   `tools/project_index.lua` - RAG and project indexing
     -   **Benefits**: Better code organization, easier to test individual components

 4.  **UI Layout Fix** ✅
     -   **Problem**: Single window layout instead of preferred 20%/80% split
     -   **Solution**: Implemented proper split layout:
         -   Result window (80% top) for AI responses
         -   Input window (20% bottom) for user input
         -   Separate buffers for each window
         -   Proper cursor positioning and focus management
     -   **Benefits**: Better user experience, matches user preferences

 5.  **Multiple Response Prevention** ✅
     -   **Problem**: AI giving 3 responses to single "hi" message
     -   **Solution**: Implemented robust state management:
         -   `is_streaming` and `processing_message` flags
         -   Unique message IDs for tracking
         -   Keymap deduplication with `pcall(vim.keymap.del)`
         -   Extensive debug logging for troubleshooting
     -   **Benefits**: Prevents duplicate responses, better error handling

 6.  **Circular Dependency Resolution** ✅
     -   **Problem**: Circular dependencies between chat modules
     -   **Solution**: Created dedicated `chat/state.lua` for shared state
     -   **Benefits**: Clean module separation, no circular dependencies

 7.  **Provider Configuration Fix** ✅
     -   **Problem**: Provider not receiving configuration properly
     -   **Solution**: Fixed provider instantiation in `providers/init.lua`
     -   **Benefits**: Proper configuration handling, working embeddings

 8.  **Userdata Concatenation Errors** ✅
     -   **Problem**: `attempt to concatenate local 'chunk' (a userdata value)`
     -   **Solution**: Added robust type and `vim.NIL` checks in provider responses
     -   **Benefits**: Prevents crashes from invalid response data

 9.  **Cursor Positioning and Completion Issues** ✅
     -   **Problem**: Cursor in wrong place, completion interfering with AI responses
     -   **Solution**: 
         -   Added bounds checking and `pcall` for cursor positioning
         -   Disabled completion for chat buffers
         -   Temporary completion disable during input
     -   **Benefits**: Better UI experience, no completion interference

 ### **Previous Fixes (Pre-Refactoring):**

 10. **`<leader>aa` Keymap Conflict** ✅
     -   **Problem**: First press opened completion instead of chat
     -   **Solution**: Changed completion toggle from `<leader>cc` to `<leader>tc`
     -   **Files**: `completion.lua:347`, `flux.lua:23`

 11. **Tab Completion Integration** ✅
     -   **Problem**: Tab conflicts between Flux, nvim-cmp, supermaven
     -   **Solution**: Integrated Flux into nvim-cmp Tab handler with priority system
     -   **Files**: `nvim-cmp.lua:39-48`, removed conflicting Tab keymap from `completion.lua`

 12. **AI Not Responding to Complex Requests** ✅
     -   **Problem**: "read main.py and update flux.md" wasn't parsed correctly
     -   **Solutions**:
         -   Enhanced pattern matching for multi-file operations
         -   Added `@UPDATE` command for existing file overwrites
         -   Created `handle_complex_file_request()` function
         -   Improved AI prompting with clear command instructions
     -   **Files**: `chat.lua:212-220, 335-386, 570-598, 772-809`

 13. **Response Window Focus Issue** ✅
     -   **Problem**: AI responses appeared in input window instead of chat
     -   **Solution**: Enhanced focus management and window switching
     -   **Files**: `chat.lua:1000-1021`, improved `scroll_to_bottom()` and `add_to_chat()`

 14. **Plugin Loading & Circular Dependency** ✅
     -   **Problem**: `could not require('flux')` error during plugin loading.
     -   **Solution**: Refactored plugin loading to use `lazy.nvim`'s `config` function as the primary entry point. Resolved
 circular dependencies by lazy-loading `config` in `simple-llm.lua`, `completion.lua`, and `ui/error_handler.lua`. Renamed
 `init.lua` to `flux.lua` for better convention.
     -   **Files**: `plugin/flux.lua`, `lua/flux.lua` (formerly `init.lua`), `lua/simple-llm.lua`, `lua/completion.lua`,
 `lua/ui/error_handler.lua`.

 15. **LLM Outputting Commands & `vim.NIL`** ✅
     -   **Problem**: LLM outputted `@EDIT` or `@READ` commands and `vim.NIL` in general conversation.
     -   **Solution**: Refined system prompt to explicitly instruct LLM to only output commands when performing file operations.
 Ensured `chunk_info.text` is never `nil` during embedding retrieval.
     -   **Files**: `lua/chat.lua`, `lua/embedding.lua`.
 
  ---
 
   ## 🚀 **How It Works - Technical Flow**

 ### **Chat Message Processing Flow:**
 1.  User types in input buffer → `chat/input.lua:send_message()`
 2.  **Pattern Matching**:
     -   `#{buffer}` → `tools/buffer_ref.lua:handle_buffer_reference()`
     -   Complex file ops → `tools/file_ops.lua:handle_complex_file_request()`
     -   Simple reads → `tools/file_ops.lua:handle_read()`
     -   Regular chat → `chat/messages.lua:process_regular_message()`
 3.  **RAG Context Augmentation (for regular chat):**
     -   User query is embedded using the embedding model via `providers/llama_cpp.lua:embed()`
     -   Relevant code chunks are retrieved from the project index via `tools/project_index.lua:find_relevant_chunks()`
     -   These chunks are prepended to the LLM prompt.
 4.  **Enhanced Prompt Building** with context + history + capabilities
 5.  **Async LLM Request** via `providers/llama_cpp.lua:stream()` (streaming!)
 6.  **Streaming Response Processing:** Tokens are received and appended to result buffer in real-time via `chat/streaming.lua:update_chat_stream()`
 7.  **Response Processing** for special commands (`@READ`, `@UPDATE`, etc.) via `chat/streaming.lua:process_llm_response()`
 8.  **UI Updates** with progress indicators and window focus management via `chat/ui.lua`
 
   ### **File Operation Commands:**
 -   AI receives instructions about available commands in every prompt.
 -   AI responds with special syntax: `@READ filename`, `@UPDATE filename`, etc.
 -   Commands are parsed and executed by `chat/streaming.lua:process_llm_response()`.
 -   Results shown in result buffer with status indicators via `ui/progress.lua`.

 ### **Project Indexing Flow:**
 1.  User runs `:FluxIndexProject`.
 2.  `tools/project_index.lua:index_project()` glob-searches project files based on configured patterns.
 3.  File contents are chunked via `tools/project_index.lua:split_into_chunks()`.
 4.  Each chunk is sent to the embedding model via `providers/llama_cpp.lua:embed()`.
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
 
   ### **If RAG Context is Missing/Incorrect:**
 1.  Ensure both generator and embedding `llama-server` instances are running.
 2.  Verify `project_root` is correctly set in your `lazy.nvim` config.
 3.  Run `:FluxIndexProject` to build/update the embeddings.
 4.  Check `flux_embeddings.json` file for content.
 5.  Check provider configuration in `providers/llama_cpp.lua` for embedding model settings.
 
  ---
 
  ## 🎯 **Development Context**
 
  ### **Built Because:**
  -   Existing AI plugins (Avante, CodeCompanion) were too complex to configure.
  -   Needed direct control over LLM integration.
  -   Wanted fast, simple, reliable AI assistance.
  -   Required file operation capabilities.
  -   Aimed for a "thinking partner" AI with project-wide context.
 
   ### **Success Metrics:**
 -   **Modular architecture** - Clean separation of concerns, easy to maintain and extend
 -   **Direct llama-server** integration (no API keys).
 -   **Working in hours** vs days of configuration.
 -   **Exact features needed** - no bloat.
 -   **Project-wide context** via RAG.
 -   **Streaming responses** for better UX.
 -   **Robust error handling** and configurable setup.
 -   **Provider abstraction** - Easy to add new LLM providers (Ollama support planned)
 -   **Proper UI layout** - 20%/80% split with separate input and result windows
 
  ### **Plugin Philosophy:**
  -   If you can't understand it, you can't fix it.
  -   Direct is better than abstracted.
  -   Performance over features.
  -   Simplicity over complexity.
 
  ---
 
   **Last Updated**: Session where we completed major refactoring, implemented modular architecture, fixed UI layout, and resolved multiple response issues.

 **Status**: ✅  All major features implemented, plugin significantly enhanced with clean modular architecture.

 ---

 ## 🚀 **Next Steps & Planned Improvements**

 ### **Immediate Priorities:**
 1. **Ollama Provider Implementation** - Add support for Ollama (for laptop usage)
 2. **Markdown Rendering** - Improve markdown syntax highlighting and rendering
 3. **Status Bar Integration** - Add status bar in footer for better UX
 4. **Testing & Validation** - Test all features after refactoring

 ### **Future Enhancements:**
 1. **Additional Providers** - Support for other LLM APIs (OpenAI, Anthropic, etc.)
 2. **Advanced RAG** - Better chunking strategies and context retrieval
 3. **Code Actions** - LSP-style code actions and quick fixes
 4. **Project Templates** - Pre-configured project templates and workflows
 5. **Performance Optimization** - Caching and optimization for large projects

 ### **Known Issues to Address:**
 1. **Legacy Modules** - `simple-llm.lua` and `embedding.lua` are deprecated but still present
 2. **Error Handling** - Some edge cases in provider communication
 3. **Configuration** - More flexible configuration options
 4. **Documentation** - Update README.md to reflect new architecture
