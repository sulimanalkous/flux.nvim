local M = {}

-- Index project files for RAG
function M.index_project()
  local handle = require("ui.progress").start("index", "Indexing project files...")
  
  -- Get current working directory
  local cwd = vim.fn.getcwd()
  local embeddings_data = {}
  
  -- Get plugin source root for filtering
  local plugin_source_root = vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ":h:h:h")
  
  -- Find all files in the project
  local files = vim.fn.globpath(cwd, "**/*", false, true)
  local processed_files = 0
  local total_chunks = 0
  
  for _, file_path in ipairs(files) do
    -- Skip directories and non-text files
    if vim.fn.isdirectory(file_path) == 0 and vim.fn.filereadable(file_path) == 1 then
      local filetype = vim.fn.fnamemodify(file_path, ":e")
      
      -- Skip binary files and common non-code files
      if not M.is_binary_file(filetype) and not M.should_skip_file(file_path) then
        -- Skip plugin's own source files
        if not file_path:find(plugin_source_root, 1, true) then
          local success, chunks = pcall(M.process_file, file_path)
          if success and chunks then
            embeddings_data[file_path] = chunks
            processed_files = processed_files + 1
            total_chunks = total_chunks + #chunks
          end
        end
      end
    end
  end
  
  -- Save embeddings data
  M.save_embeddings(embeddings_data)
  
  require("ui.progress").complete(handle, string.format("Indexed %d files, %d chunks", processed_files, total_chunks))
  vim.notify(string.format("Flux.nvim: Project indexed! %d files, %d chunks", processed_files, total_chunks), vim.log.levels.INFO)
end

-- Process a single file
function M.process_file(file_path)
  local lines = vim.fn.readfile(file_path)
  local content = table.concat(lines, "\n")
  
  -- Split content into chunks
  local chunks = M.split_into_chunks(content, file_path)
  
  -- Generate embeddings for each chunk
  local providers = require("providers")
  local provider = providers.get_provider()
  
  for i, chunk in ipairs(chunks) do
    provider:embed(chunk.text, function(embedding, err)
      if embedding then
        chunk.embedding = embedding
      else
        vim.notify("Failed to generate embedding for chunk " .. i .. " in " .. file_path, vim.log.levels.WARN)
      end
    end)
  end
  
  return chunks
end

-- Split content into chunks
function M.split_into_chunks(content, file_path)
  local chunks = {}
  local lines = vim.split(content, "\n")
  local chunk_size = 1000 -- characters per chunk
  local current_chunk = ""
  local chunk_lines = {}
  
  for i, line in ipairs(lines) do
    if #current_chunk + #line > chunk_size and #current_chunk > 0 then
      -- Save current chunk
      table.insert(chunks, {
        text = current_chunk,
        start_line = i - #chunk_lines,
        end_line = i - 1,
        file_path = file_path
      })
      
      -- Start new chunk
      current_chunk = line
      chunk_lines = {line}
    else
      current_chunk = current_chunk .. (current_chunk ~= "" and "\n" or "") .. line
      table.insert(chunk_lines, line)
    end
  end
  
  -- Add final chunk
  if current_chunk ~= "" then
    table.insert(chunks, {
      text = current_chunk,
      start_line = #lines - #chunk_lines + 1,
      end_line = #lines,
      file_path = file_path
    })
  end
  
  return chunks
end

-- Find relevant chunks for a query
function M.find_relevant_chunks(query_embedding, num_results)
  local embeddings_data = M.load_embeddings()
  if not embeddings_data then
    return {}
  end
  
  local results = {}
  local plugin_source_root = vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ":h:h:h")
  
  for file_path, file_chunks_data in pairs(embeddings_data) do
    -- Skip plugin's own source files (only if we're in a plugin directory)
    if plugin_source_root ~= "." and file_path:find(plugin_source_root, 1, true) then
      goto continue_file_loop
    end
    
    for _, chunk_data in ipairs(file_chunks_data) do
      if chunk_data.embedding and #chunk_data.embedding > 0 then
        local similarity = M.cosine_similarity(query_embedding, chunk_data.embedding)
        table.insert(results, { file_path = file_path, text = chunk_data.text, similarity = similarity })
      end
    end
    
    ::continue_file_loop::
  end
  
  -- Sort by similarity and return top results
  table.sort(results, function(a, b) return a.similarity > b.similarity end)
  return vim.list_slice(results, 1, num_results or 5)
end

-- Calculate cosine similarity
function M.cosine_similarity(vec1, vec2)
  if #vec1 ~= #vec2 then
    return 0
  end
  
  local dot_product = 0
  local norm1 = 0
  local norm2 = 0
  
  for i = 1, #vec1 do
    dot_product = dot_product + vec1[i] * vec2[i]
    norm1 = norm1 + vec1[i] * vec1[i]
    norm2 = norm2 + vec2[i] * vec2[i]
  end
  
  if norm1 == 0 or norm2 == 0 then
    return 0
  end
  
  return dot_product / (math.sqrt(norm1) * math.sqrt(norm2))
end

-- Save embeddings data
function M.save_embeddings(embeddings_data)
  local data_dir = vim.fn.stdpath("data") .. "/flux_nvim"
  vim.fn.mkdir(data_dir, "p")
  
  local file_path = data_dir .. "/embeddings.json"
  local json_data = vim.fn.json_encode(embeddings_data)
  vim.fn.writefile(vim.split(json_data, "\n"), file_path)
end

-- Load embeddings data
function M.load_embeddings()
  local data_dir = vim.fn.stdpath("data") .. "/flux_nvim"
  local file_path = data_dir .. "/embeddings.json"
  
  if vim.fn.filereadable(file_path) == 0 then
    return nil
  end
  
  local lines = vim.fn.readfile(file_path)
  local json_data = table.concat(lines, "\n")
  local success, data = pcall(vim.fn.json_decode, json_data)
  
  if success then
    return data
  else
    return nil
  end
end

-- Check if file should be skipped
function M.should_skip_file(file_path)
  local skip_patterns = {
    "%.git/", "%.svn/", "%.hg/", "node_modules/", "%.o$", "%.so$", "%.dylib$",
    "%.exe$", "%.dll$", "%.class$", "%.pyc$", "%.pyo$", "__pycache__/",
    "%.log$", "%.tmp$", "%.temp$", "%.swp$", "%.swo$", "%.swn$"
  }
  
  for _, pattern in ipairs(skip_patterns) do
    if file_path:match(pattern) then
      return true
    end
  end
  
  return false
end

-- Check if file is binary
function M.is_binary_file(filetype)
  local binary_types = {
    "png", "jpg", "jpeg", "gif", "bmp", "ico", "svg", "pdf", "zip", "tar", "gz",
    "rar", "7z", "mp3", "mp4", "avi", "mov", "wmv", "flv", "webm", "exe", "dll",
    "so", "dylib", "class", "pyc", "pyo"
  }
  
  for _, type in ipairs(binary_types) do
    if filetype == type then
      return true
    end
  end
  
  return false
end

-- Register the tool
local tools = require("tools")
tools.register("project_index", M)

return M
