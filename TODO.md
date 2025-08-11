# Flux.nvim Development TODO

This file tracks the planned improvements and new features for the plugin.

## Core Improvements

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

## UI/UX & Quality of Life

- [x] **Task 4: UI Enhancements & Code Cleanup**
  - [x] Create a `lua/utils.lua` file and move shared functions like `string.trim` there.
  - [ ] (Optional) Integrate `Telescope.nvim` for the `/buffer` picker UI.

## Advanced Features

- [x] **Task 5: Implement RAG for Project-Wide Context (Embedding Idea)**
  - [x] Extend the configuration to support a second "embedding" model endpoint.
  - [x] Create a `:FluxIndexProject` command to generate and store embeddings for all project files.
  - [x] Update the chat logic to augment prompts with relevant context retrieved from the index.
