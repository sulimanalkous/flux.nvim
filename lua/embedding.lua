-- Embedding module for Flux.nvim
local M = {}

local api = vim.api
local fn = vim.fn
local simple_llm = require("simple-llm")
local progress = require("ui.progress")

local EMBEDDINGS_FILE = vim.fn.expand(fn.stdpath("data") .. "/flux_embeddings.json")
local MAX_CHUNK_SIZE = 512 -- Max tokens for embedding model input

-- Function to get embedding from the embedding model
-- This will be a new function in simple-llm.lua
local function get_embedding(text, callback)
  simple_llm.ask_embedding(text, callback)
end

-- Function to split text into chunks suitable for embedding model
local function chunk_text(text)
  local chunks = {}
  local current_chunk = ""
  for word in text:gmatch("%S+") do -- Split by whitespace
    if #current_chunk + #word + 1 <= MAX_CHUNK_SIZE then
      current_chunk = current_chunk .. (current_chunk == "" and "" or " ") .. word
    else
      table.insert(chunks, current_chunk)
      current_chunk = word
    end
  end
  if current_chunk ~= "" then
    table.insert(chunks, current_chunk)
  end
  return chunks
end

-- Function to index the project files
function M.index_project()
  local handle = progress.start("indexing", "Indexing project files...")
  local config = require("flux").config
  local project_root = config.project_root
  local embeddings_data = {}

  -- Define file patterns to include
  local include_patterns = {
    "**/*.lua",
    "**/*.py",
    "**/*.js",
    "**/*.ts",
    "**/*.tsx",
    "**/*.json",
    "**/*.md",
    "**/*.txt",
  }

  -- Find all relevant files
  local files_to_index = {}
  for _, pattern in ipairs(include_patterns) do
    local found_files = vim.fn.glob(project_root .. "/" .. pattern, true, true)
    for _, file_path in ipairs(found_files) do
      table.insert(files_to_index, file_path)
    end
  end

  if #files_to_index == 0 then
    progress.error(handle, "No files found to index.")
    vim.notify("Flux.nvim: No files found to index in project.", vim.log.levels.WARN)
    return
  end

  progress.update(handle, string.format("Found %d files. Generating embeddings...", #files_to_index))

  local indexed_count = 0
  local total_files = #files_to_index

  local function process_next_file()
    if indexed_count >= total_files then
      -- All files processed, save embeddings
      local json_data = vim.json.encode(embeddings_data)
      local file = io.open(EMBEDDINGS_FILE, "w")
      if file then
        file:write(json_data)
        file:close()
        progress.complete(handle, string.format("Project indexed successfully. %d files processed.", total_files))
        vim.notify("Flux.nvim: Project indexed successfully!", vim.log.levels.INFO)
      else
        progress.error(handle, "Failed to save embeddings file.")
        vim.notify("Flux.nvim: Failed to save embeddings to " .. EMBEDDINGS_FILE, vim.log.levels.ERROR)
      end
      return
    end

    local file_path = files_to_index[indexed_count + 1]
    indexed_count = indexed_count + 1

    progress.update(handle, string.format("Indexing file %d/%d: %s", indexed_count, total_files, file_path))

    local ok, lines = pcall(vim.fn.readfile, file_path)
    if not ok then
      vim.notify(string.format("Flux.nvim: Could not read file %s", file_path), vim.log.levels.WARN)
      process_next_file() -- Skip to next file
      return
    end
    local file_content = table.concat(lines, "\n")

    local chunks = chunk_text(file_content)
    local file_embeddings = {}
    local chunk_index = 0
    local total_chunks = #chunks

    local function process_next_chunk()
      if chunk_index >= total_chunks then
        embeddings_data[file_path] = file_embeddings
        process_next_file() -- Move to next file
        return
      end

      local chunk_text_to_embed = chunks[chunk_index + 1]
      chunk_index = chunk_index + 1

      get_embedding(chunk_text_to_embed, function(embedding, err)
        if embedding then
          local text_to_store = chunk_text_to_embed or ""
          table.insert(file_embeddings, { text = text_to_store, embedding = embedding })
          process_next_chunk()
        else
          vim.notify(string.format("Flux.nvim: Failed to get embedding for chunk in %s: %s", file_path, err or "Unknown error"), vim.log.levels.ERROR)
          process_next_chunk() -- Try next chunk/file even if one fails
        end
      end)
    end
    process_next_chunk()
  end
  process_next_file()
end

-- Helper function for cosine similarity
local function cosine_similarity(vec1, vec2)
  -- Debug: Check vector dimensions
  if #vec1 ~= #vec2 then
    vim.notify(string.format("Flux.nvim: Vector dimension mismatch: %d vs %d", #vec1, #vec2), vim.log.levels.ERROR)
    return 0
  end

  local dot_product = 0
  local magnitude1 = 0
  local magnitude2 = 0

  for i = 1, #vec1 do
    dot_product = dot_product + (vec1[i] * vec2[i])
    magnitude1 = magnitude1 + (vec1[i] * vec1[i])
    magnitude2 = magnitude2 + (vec2[i] * vec2[i])
  end

  magnitude1 = math.sqrt(magnitude1)
  magnitude2 = math.sqrt(magnitude2)

  if magnitude1 == 0 or magnitude2 == 0 then
    return 0 -- Avoid division by zero
  else
    local similarity = dot_product / (magnitude1 * magnitude2)
    -- Debug: Log extreme values
    if similarity < -1 or similarity > 1 then
      vim.notify(string.format("Flux.nvim: Invalid similarity value: %.3f", similarity), vim.log.levels.WARN)
    end
    return similarity
  end
end

-- Function to load embeddings data from file
function M.load_embeddings()
  local file = io.open(EMBEDDINGS_FILE, "r")
  if file then
    local content = file:read("*all")
    file:close()
    local ok, data = pcall(vim.json.decode, content)
    if ok then
      return data
    else
      vim.notify("Flux.nvim: Failed to decode embeddings file: " .. EMBEDDINGS_FILE, vim.log.levels.ERROR)
      return nil
    end
  else
    vim.notify("Flux.nvim: Embeddings file not found: " .. EMBEDDINGS_FILE, vim.log.levels.WARN)
    return nil
  end
end

-- Function to find relevant chunks based on query embedding
function M.find_relevant_chunks(query_embedding, num_results)
  num_results = num_results or 5
  local embeddings_data = M.load_embeddings()
  if not embeddings_data then 
    vim.notify("Flux.nvim: No embeddings data found. Run :FluxIndexProject first.", vim.log.levels.DEBUG)
    return {} 
  end

  -- Debug: Check query embedding
  if not query_embedding or #query_embedding == 0 then
    vim.notify("Flux.nvim: Query embedding is empty or invalid", vim.log.levels.ERROR)
    return {}
  end

  local results = {}
  local plugin_source_root = vim.fn.fnamemodify(vim.fn.expand("<sfile>:p"), ":h"):gsub("/lua$", "") -- Get plugin root from current file path
  local total_chunks_checked = 0
  local valid_chunks_checked = 0

  for file_path, file_chunks_data in pairs(embeddings_data) do
    -- Skip plugin's own source files (only if we're in a plugin directory)
    if plugin_source_root ~= "." and file_path:find(plugin_source_root, 1, true) then
      goto continue_file_loop
    end

    for _, chunk_data in ipairs(file_chunks_data) do
      total_chunks_checked = total_chunks_checked + 1
      if chunk_data.embedding and #chunk_data.embedding > 0 then
        valid_chunks_checked = valid_chunks_checked + 1
        local similarity = cosine_similarity(query_embedding, chunk_data.embedding)
        table.insert(results, { file_path = file_path, text = chunk_data.text, similarity = similarity })
      end
    end
    ::continue_file_loop::
  end

  -- Sort by similarity in descending order
  table.sort(results, function(a, b) return a.similarity > b.similarity end)

  -- Return top N results
  local top_results = {}
  for i = 1, math.min(num_results, #results) do
    table.insert(top_results, results[i])
  end

  -- Debug: Log detailed information
  vim.notify(string.format("Flux.nvim: Checked %d total chunks, %d valid chunks, found %d results", total_chunks_checked, valid_chunks_checked, #results), vim.log.levels.DEBUG)
  
  if #top_results > 0 then
    vim.notify(string.format("Flux.nvim: Found %d relevant chunks (best similarity: %.3f)", #top_results, top_results[1].similarity), vim.log.levels.DEBUG)
  else
    vim.notify("Flux.nvim: No relevant chunks found for query", vim.log.levels.DEBUG)
  end

  return top_results
end

return M