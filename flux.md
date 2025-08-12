
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
 - **Proper UI Layout** - Sidebar container with result window (auto height), input window (2 lines), status window (1 line)
 - **File Operations** - AI can read, create, update files via special commands:
   - `@READ filename` - Read any file/directory
   - `@CREATE filename` - Create new files
   - `@UPDATE filename` - Update/overwrite existing files
   - `@EDIT` - Edit current buffer with diff interface
   - `@LIST directory/` - List directory contents
 - **Buffer References** - `#{buffer}` to reference current/pinned files
 - **Command System** - `/help`, `/clear`, `/buffer` for chat management
 - **Robust State Management** - Prevents multiple responses and handles errors gracefully
 - **Action-Oriented AI** - Actually performs file operations instead of just explaining

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

 ### 5. **RAG & Project Indexing** (`tools/project_index.lua`) - IMPROVED!
 - **Smart Chunking** - Splits files into meaningful chunks for better context
 - **Embedding Generation** - Uses separate embedding model (localhost:1235)
 - **Similarity Search** - Finds relevant code snippets for user queries
 - **Project Context** - Automatically provides relevant code context to AI
 - **Synchronous Processing** - Fixed embedding generation to wait for completion
 - **Error Recovery** - Handles embedding failures gracefully

 ### 6. **File Operations** (`tools/file_ops.lua`) - NEW!
 - **@READ Command** - Read files and directories
 - **@CREATE Command** - Create new files with content
 - **@UPDATE Command** - Update existing files
 - **@EDIT Command** - Edit current buffer
 - **Progress Tracking** - Visual feedback for file operations
 - **Error Handling** - Graceful failure handling

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
 
   ## 🔧 **Recent Fixes & Improvements**

 ### **UI Layout & Window Management**
 - ✅ **Fixed sidebar container layout** - Proper 20%/80% split with result, input, and status windows
 - ✅ **Fixed window height issues** - Input window (2 lines), status window (1 line)
 - ✅ **Fixed window ID handling** - Proper `vim.fn.win_id2win()` usage
 - ✅ **Fixed swapped window heights** - Automatic detection and correction

 ### **Command Registration & Availability**
 - ✅ **Fixed global command availability** - Commands now available immediately on plugin load
 - ✅ **Fixed circular dependency** - Removed duplicate setup functions
 - ✅ **Fixed plugin loading** - Proper lazy.nvim integration
 - ✅ **Fixed command architecture** - All commands go through main `flux` module

 ### **Embedding & RAG System**
 - ✅ **Fixed embedding generation** - Synchronous processing with timeout protection
 - ✅ **Fixed JSON parsing errors** - Handle empty responses gracefully
 - ✅ **Fixed duplicate callbacks** - Prevent race conditions in embedding requests
 - ✅ **Fixed project indexing** - Proper chunk processing and storage

 ### **AI Behavior & File Operations**
 - ✅ **Enhanced AI personality** - More conversational and action-oriented
 - ✅ **Fixed file operation commands** - AI now actually performs file operations
 - ✅ **Improved prompt engineering** - Clear instructions for when to use @UPDATE, @CREATE, etc.
 - ✅ **Fixed syntax errors** - Resolved Lua string concatenation issues

 ### **Error Handling & Debugging**
 - ✅ **Removed debug prints** - Clean user experience without debug spam
 - ✅ **Fixed error handling** - Graceful handling of various error conditions
 - ✅ **Added progress indicators** - Visual feedback for long operations

 ---

 ## 🚀 **Usage Examples**

 ### **Basic Chat**
 ```vim
 :FluxAgent          " Open chat interface
 <leader>ac          " Toggle chat
 ```

 ### **Project Indexing**
 ```vim
 :FluxIndexProject   " Index project for RAG
 ```

 ### **File Operations via AI**
 ```
 " Add understanding to flux.md file"
 " Update the README with new features"
 " Create a new configuration file"
 ```

 ### **Complex Reasoning**
 ```vim
 :FluxReason "How can we improve the architecture?"
 ```

 ---

 ## 🎯 **Next Steps & Planned Improvements**

 ### **Short Term**
 - [ ] **Ollama Provider** - Add support for Ollama as alternative to llama.cpp
 - [ ] **Markdown Rendering** - Improve markdown display in chat
 - [ ] **Status Bar Integration** - Better fidget.nvim integration
 - [ ] **Configuration UI** - Easy configuration management

 ### **Medium Term**
 - [ ] **Multi-Model Support** - Switch between different LLM models
 - [ ] **Advanced RAG** - Better context retrieval and ranking
 - [ ] **Code Analysis** - Static analysis integration
 - [ ] **Testing Framework** - Automated testing for the plugin

 ### **Long Term**
 - [ ] **Plugin Ecosystem** - Allow third-party extensions
 - [ ] **Cloud Integration** - Support for cloud LLM providers
 - [ ] **Advanced UI** - More sophisticated chat interface
 - [ ] **Performance Optimization** - Further speed improvements

 ---

 ## 🔍 **Troubleshooting**

 ### **Common Issues**
 1. **Commands not available** - Restart Neovim or run `:Lazy reload flux.nvim`
 2. **Embedding errors** - Check if embedding server is running on port 1235
 3. **File operations not working** - Ensure AI uses @UPDATE/@CREATE commands properly
 4. **UI layout issues** - Check window management in `chat/ui.lua`

 ### **Debug Commands**
 ```vim
 :FluxCheckEmbeddings    " Check embedding status
 :FluxTestEmbeddings     " Test embedding functionality
 :FluxInspectEmbeddings  " Inspect stored embeddings
 ```

 ---

 ## 📝 **Development Notes**

 - **Modular Architecture** - Each component is self-contained and testable
 - **State Management** - Centralized state in `chat/state.lua` to prevent circular dependencies
 - **Provider Abstraction** - Easy to add new LLM providers
 - **Tool System** - Extensible tool system for file operations and utilities
 - **Error Recovery** - Graceful handling of network and processing errors

 This architecture makes Flux.nvim maintainable, debuggable, and extensible while providing a powerful AI coding partner experience.
