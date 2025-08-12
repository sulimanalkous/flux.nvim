# Flux.nvim Development TODO

This file tracks the planned improvements and new features for the plugin.

## ✅ **Completed Tasks**

### **Core Architecture & Refactoring**
- [x] **Task 1: Make LLM Server Configurable**
  - [x] Create a `setup` function that accepts a configuration table.
  - [x] Allow users to specify `host` and `port` for the LLM server.
  - [x] Update `simple-llm.lua` to use the configured URL.

- [x] **Task 2: Improve Robustness & Portability**
  - [x] Replace hardcoded `/tmp/` file paths with `vim.fn.tempname()`.
  - [x] Integrate the existing retry logic from `ui/error_handler.lua` into the main `ask_llama` function.
  - [x] Enable and test the health monitoring feature.

- [x] **Task 3: Implement Streaming Chat Responses**
  - [x] Modify the `curl` command in `simple-llm.lua` to support streaming (`--no-buffer`).
  - [x] Update the `on_stdout` callback to process response chunks in real-time.
  - [x] Append incoming text chunks to the chat buffer to create a "live" typing effect.

- [x] **Task 4: UI Enhancements & Code Cleanup**
  - [x] Create a `lua/utils.lua` file and move shared functions like `string.trim` there.
  - [x] Implement proper sidebar container layout with result, input, and status windows
  - [x] Fix window height management and cursor positioning

- [x] **Task 5: Implement RAG for Project-Wide Context**
  - [x] Extend the configuration to support a second "embedding" model endpoint.
  - [x] Create a `:FluxIndexProject` command to generate and store embeddings for all project files.
  - [x] Update the chat logic to augment prompts with relevant context retrieved from the index.
  - [x] Fix embedding generation with synchronous processing and error handling

### **Major Refactoring & Modular Architecture**
- [x] **Task 6: Modular Architecture Refactoring**
  - [x] Split monolithic `chat.lua` (1339 lines) into focused modules
  - [x] Create `chat/` subdirectory with separate modules for state, UI, input, messages, streaming, commands
  - [x] Implement provider abstraction system for different LLM providers
  - [x] Create tools system for file operations and utilities
  - [x] Resolve circular dependencies with centralized state management

- [x] **Task 7: File Operations System**
  - [x] Implement `@READ`, `@CREATE`, `@UPDATE`, `@EDIT` commands
  - [x] Create file operations tool with progress tracking
  - [x] Add error handling and validation for file operations
  - [x] Make AI actually perform file operations instead of just explaining

- [x] **Task 8: Command System & Plugin Loading**
  - [x] Fix global command availability (FluxAgent, FluxIndexProject, etc.)
  - [x] Resolve circular dependency issues in plugin loading
  - [x] Implement proper lazy.nvim integration
  - [x] Create action-oriented AI that performs requested tasks

- [x] **Task 9: Error Handling & Debugging**
  - [x] Fix embedding generation race conditions
  - [x] Handle JSON parsing errors gracefully
  - [x] Remove debug prints for clean user experience
  - [x] Add progress indicators for long operations

## 🚀 **Current Tasks**

### **Short Term (Next 1-2 weeks)**
- [ ] **Task 10: Ollama Provider Implementation**
  - [ ] Create `providers/ollama.lua` for Ollama integration
  - [ ] Add provider selection in configuration
  - [ ] Test with different Ollama models
  - [ ] Update documentation for Ollama setup

- [ ] **Task 11: Markdown Rendering Improvements**
  - [ ] Implement proper markdown parsing in chat
  - [ ] Add syntax highlighting for code blocks
  - [ ] Support for tables, lists, and other markdown elements
  - [ ] Fix markdown leakage issues

- [ ] **Task 12: Enhanced Status Integration**
  - [ ] Improve fidget.nvim integration for progress indicators
  - [ ] Add status bar in footer for better UX
  - [ ] Show current model and server status
  - [ ] Add connection health indicators

### **Medium Term (Next 1-2 months)**
- [ ] **Task 13: Configuration Management**
  - [ ] Create configuration UI for easy setup
  - [ ] Add configuration validation
  - [ ] Support for per-project configuration
  - [ ] Configuration migration tools

- [ ] **Task 14: Advanced RAG Features**
  - [ ] Implement better chunking strategies
  - [ ] Add semantic search improvements
  - [ ] Support for multiple embedding models
  - [ ] Add context ranking and filtering

- [ ] **Task 15: Testing Framework**
  - [ ] Create unit tests for core modules
  - [ ] Add integration tests for file operations
  - [ ] Implement automated testing pipeline
  - [ ] Add performance benchmarks

### **Long Term (Future)**
- [ ] **Task 16: Multi-Model Support**
  - [ ] Support for switching between different LLM models
  - [ ] Model comparison and benchmarking
  - [ ] Automatic model selection based on task
  - [ ] Support for cloud LLM providers (OpenAI, Anthropic)

- [ ] **Task 17: Plugin Ecosystem**
  - [ ] Create extension API for third-party plugins
  - [ ] Support for custom tools and providers
  - [ ] Plugin marketplace or registry
  - [ ] Documentation for plugin developers

- [ ] **Task 18: Advanced UI Features**
  - [ ] More sophisticated chat interface
  - [ ] Support for rich media (images, diagrams)
  - [ ] Collaborative features for team development
  - [ ] Custom themes and styling

## 🔧 **Technical Debt & Improvements**

### **Code Quality**
- [ ] **Task 19: Code Cleanup**
  - [ ] Remove deprecated modules (`simple-llm.lua`, `embedding.lua`)
  - [ ] Add comprehensive error handling
  - [ ] Improve code documentation
  - [ ] Add type annotations where possible

### **Performance**
- [ ] **Task 20: Performance Optimization**
  - [ ] Implement caching for embeddings
  - [ ] Optimize large project indexing
  - [ ] Add request batching for better throughput
  - [ ] Profile and optimize memory usage

### **Documentation**
- [ ] **Task 21: Documentation Updates**
  - [ ] Update README.md with new architecture
  - [ ] Create user guide with examples
  - [ ] Add developer documentation
  - [ ] Create video tutorials

## 🐛 **Known Issues to Address**

### **Critical**
- [ ] **Issue 1: Legacy Module Cleanup**
  - [ ] Remove `simple-llm.lua` and `embedding.lua` completely
  - [ ] Update all references to use new provider system
  - [ ] Ensure no functionality is lost during cleanup

### **Important**
- [ ] **Issue 2: Error Recovery**
  - [ ] Improve error recovery for network failures
  - [ ] Add automatic retry mechanisms
  - [ ] Better error messages for users

### **Nice to Have**
- [ ] **Issue 3: Configuration Flexibility**
  - [ ] More granular configuration options
  - [ ] Environment-specific configurations
  - [ ] Dynamic configuration updates

---

## 📊 **Progress Summary**

- **Total Tasks**: 21 planned tasks
- **Completed**: 9 tasks (43%)
- **In Progress**: 3 tasks (14%)
- **Remaining**: 9 tasks (43%)

**Current Focus**: Ollama provider implementation and markdown rendering improvements.

**Next Milestone**: Complete short-term tasks for a more polished user experience.
