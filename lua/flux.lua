-- Flux.nvim - Main plugin module
local M = {}

-- Default configuration
M.config = {
  host = "localhost",
  port = 1234,
  project_root = vim.fn.getcwd(), -- Default to Neovim's current working directory
  -- Configuration for a potential second model (for embedding)
  embedding = {
    host = "localhost",
    port = 1235, -- Assuming a different port for the embedding model
    model = "text-embedding", -- Embedding model name
  }
}

-- Plugin setup
function M.setup(user_config)
  -- Merge user config with defaults
  M.config = vim.tbl_deep_extend("force", M.config, user_config or {})

  -- Initialize new module architecture
  local providers = require("providers")
  local tools = require("tools")
  local chat = require("chat")
  
  -- Setup providers and tools
  providers.setup(M.config)
  tools.setup()
  chat.setup()

  -- Import legacy modules
  local simple_llm = require("simple-llm")
  local edit = require("edit")
  local completion = require("completion")
  local error_handler = require("ui.error_handler")

  -- Setup keymaps
  -- Chat
  vim.keymap.set("n", "<leader>ac", chat.toggle, { desc = "Toggle LLM Chat" })
  vim.keymap.set("n", "<leader>aa", chat.create_interface, { desc = "Open LLM Chat" })

  -- LLM operations
  vim.keymap.set("n", "<leader>lf", simple_llm.fix_code, { desc = "Fix code with LLM" })
  vim.keymap.set("v", "<leader>le", simple_llm.explain_selection, { desc = "Explain selection with LLM" })
  vim.keymap.set("n", "<leader>lp", function()
    local prompt = vim.fn.input("Ask LLM: ")
    if prompt ~= "" then
      simple_llm.ask_llama(prompt, function(response)
        vim.notify(response, vim.log.levels.INFO)
      end)
    end
  end, { desc = "Ask LLM prompt" })
  
  -- Agent-like interactions
  vim.keymap.set("n", "<leader>la", function()
    local prompt = vim.fn.input("Let's think about: ")
    if prompt ~= "" then
      local chat = require("chat")
      if chat.state.chat_buf and vim.api.nvim_buf_is_valid(chat.state.chat_buf) then
        chat.handle_complex_reasoning(prompt)
      else
        chat.create_interface()
        vim.defer_fn(function()
          chat.handle_complex_reasoning(prompt)
        end, 100)
      end
    end
  end, { desc = "Agent reasoning session" })

  -- Edit
  vim.keymap.set("v", "<leader>ae", edit.edit_selection, { desc = "Edit selection with Flux" })
  vim.keymap.set("n", "<leader>af", edit.edit_buffer, { desc = "Edit buffer with Flux" })

  -- Completion
  completion.setup()

  -- Health Monitoring
  vim.keymap.set("n", "<leader>ls", error_handler.manual_status_check, { desc = "Check LLM Server Status" })
  error_handler.setup_health_monitoring()

  -- Add user commands
  vim.api.nvim_create_user_command("FluxAgent", function()
    local chat = require("chat")
    if chat.state.chat_buf and vim.api.nvim_buf_is_valid(chat.state.chat_buf) then
      local win_id = vim.fn.bufwinnr(chat.state.chat_buf)
      if win_id > 0 and vim.api.nvim_win_is_valid(win_id) then
        vim.api.nvim_set_current_win(win_id)
      else
        chat.create_interface()
      end
    else
      chat.create_interface()
    end
  end, { desc = "Open Flux Agent Chat" })

  vim.api.nvim_create_user_command("FluxReason", function(opts)
    if opts.args and opts.args ~= "" then
      local chat = require("chat")
      if chat.state.chat_buf and vim.api.nvim_buf_is_valid(chat.state.chat_buf) then
        local win_id = vim.fn.bufwinnr(chat.state.chat_buf)
        if win_id > 0 and vim.api.nvim_win_is_valid(win_id) then
          chat.handle_complex_reasoning(opts.args)
        else
          chat.create_interface()
          vim.defer_fn(function()
            chat.handle_complex_reasoning(opts.args)
          end, 100)
        end
      else
        chat.create_interface()
        vim.defer_fn(function()
          chat.handle_complex_reasoning(opts.args)
        end, 100)
      end
    else
      vim.notify("Usage: FluxReason <your question>", vim.log.levels.WARN)
    end
  end, { nargs = 1, desc = "Start a reasoning session with Flux Agent" })

  vim.api.nvim_create_user_command("FluxCheckEmbeddings", function()
    local project_index = require("tools").get_tool("project_index")
    local embeddings_data = project_index.load_embeddings()
    if embeddings_data then
      local file_count = 0
      local chunk_count = 0
      for file_path, chunks in pairs(embeddings_data) do
        file_count = file_count + 1
        chunk_count = chunk_count + #chunks
      end
      vim.notify(string.format("Flux.nvim: Embeddings loaded successfully! %d files, %d chunks indexed.", file_count, chunk_count), vim.log.levels.INFO)
    else
      vim.notify("Flux.nvim: No embeddings found. Run :FluxIndexProject first.", vim.log.levels.WARN)
    end
  end, { desc = "Check if project embeddings are loaded" })

  vim.api.nvim_create_user_command("FluxIndexProject", function()
    local project_index = require("tools").get_tool("project_index")
    project_index.index_project()
  end, { desc = "Index project files for AI context" })

  vim.api.nvim_create_user_command("FluxTestEmbeddings", function(opts)
    if opts.args and opts.args ~= "" then
      local project_index = require("tools").get_tool("project_index")
      local providers = require("providers")
      local provider = providers.get_provider()
      
      vim.notify("Testing embeddings for query: " .. opts.args, vim.log.levels.INFO)
      
      provider:embed(opts.args, function(query_embedding, err)
        if err or not query_embedding then
          vim.notify("Embedding test failed: " .. (err or "Unknown error"), vim.log.levels.ERROR)
          return
        end
        
        vim.notify(string.format("Query embedding generated: %d dimensions", #query_embedding), vim.log.levels.INFO)
        
        local chunks = project_index.find_relevant_chunks(query_embedding, 3)
        if #chunks > 0 then
          vim.notify(string.format("Embedding test successful! Found %d relevant chunks.", #chunks), vim.log.levels.INFO)
          for i, chunk in ipairs(chunks) do
            local relative_path = vim.fn.fnamemodify(chunk.file_path, ":.")
            vim.notify(string.format("Chunk %d: %s (similarity: %.3f)", i, relative_path, chunk.similarity), vim.log.levels.INFO)
          end
        else
          vim.notify("No relevant chunks found. Make sure you've run :FluxIndexProject first.", vim.log.levels.WARN)
        end
      end)
    else
      vim.notify("Usage: FluxTestEmbeddings <your query>", vim.log.levels.WARN)
    end
  end, { nargs = 1, desc = "Test embeddings with a query" })

  vim.api.nvim_create_user_command("FluxInspectEmbeddings", function()
    local project_index = require("tools").get_tool("project_index")
    local embeddings_data = project_index.load_embeddings()
    
    if not embeddings_data then
      vim.notify("No embeddings data found. Run :FluxIndexProject first.", vim.log.levels.WARN)
      return
    end
    
    vim.notify("Inspecting embeddings data...", vim.log.levels.INFO)
    
    for file_path, chunks in pairs(embeddings_data) do
      local relative_path = vim.fn.fnamemodify(file_path, ":.")
      vim.notify(string.format("File: %s (%d chunks)", relative_path, #chunks), vim.log.levels.INFO)
      
      for i, chunk in ipairs(chunks) do
        if chunk.embedding then
          vim.notify(string.format("  Chunk %d: %d dimensions, text: %s", i, #chunk.embedding, chunk.text:sub(1, 50) .. "..."), vim.log.levels.INFO)
        else
          vim.notify(string.format("  Chunk %d: NO EMBEDDING, text: %s", i, chunk.text:sub(1, 50) .. "..."), vim.log.levels.ERROR)
        end
      end
    end
  end, { desc = "Inspect stored embeddings data" })

  vim.api.nvim_create_user_command("FluxTestEmbeddingServer", function()
    local providers = require("providers")
    local provider = providers.get_provider()
    local config = require("flux").config
    
    vim.notify("Testing embedding server connection...", vim.log.levels.INFO)
    vim.notify(string.format("Embedding server: %s:%d, model: %s", config.embedding.host, config.embedding.port, config.embedding.model), vim.log.levels.INFO)
    
    provider:embed("test", function(embedding, err)
      if err then
        vim.notify("Embedding server test failed: " .. err, vim.log.levels.ERROR)
        vim.notify("This suggests either:", vim.log.levels.WARN)
        vim.notify("1. The embedding server is not running on port " .. config.embedding.port, vim.log.levels.WARN)
        vim.notify("2. The model name '" .. config.embedding.model .. "' is incorrect", vim.log.levels.WARN)
        vim.notify("3. The embedding server doesn't support the /v1/embeddings endpoint", vim.log.levels.WARN)
        vim.notify("4. The embedding server is not properly configured", vim.log.levels.WARN)
      else
        vim.notify(string.format("Embedding server test successful! Generated %d dimensions", #embedding), vim.log.levels.INFO)
        vim.notify("The embedding server is working correctly!", vim.log.levels.INFO)
        
        -- Show first few values to verify it's not all zeros
        local first_few = {}
        for i = 1, math.min(5, #embedding) do
          table.insert(first_few, embedding[i])
        end
        vim.notify("First few embedding values: " .. table.concat(first_few, ", "), vim.log.levels.INFO)
      end
    end)
  end, { desc = "Test embedding server connection" })

  vim.api.nvim_create_user_command("FluxDebugSimilarity", function()
    local simple_llm = require("simple-llm")
    local embedding = require("embedding")
    
    vim.notify("Testing similarity calculation...", vim.log.levels.INFO)
    
    -- Generate embeddings for two similar texts
    simple_llm.ask_embedding("what is this project about", function(embedding1, err1)
      if err1 then
        vim.notify("Failed to generate first embedding: " .. err1, vim.log.levels.ERROR)
        return
      end
      
      simple_llm.ask_embedding("tell me about the project", function(embedding2, err2)
        if err2 then
          vim.notify("Failed to generate second embedding: " .. err2, vim.log.levels.ERROR)
          return
        end
        
        -- Test cosine similarity directly
        local function cosine_similarity(vec1, vec2)
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
            return 0
          else
            return dot_product / (magnitude1 * magnitude2)
          end
        end
        
        local similarity = cosine_similarity(embedding1, embedding2)
        vim.notify(string.format("Similarity between similar queries: %.6f", similarity), vim.log.levels.INFO)
        
        -- Test with identical vectors (should be 1.0)
        local test_vec = {1, 2, 3, 4, 5}
        local test_similarity = cosine_similarity(test_vec, test_vec)
        vim.notify(string.format("Test similarity (identical vectors): %.6f (should be 1.0)", test_similarity), vim.log.levels.INFO)
        
        -- Now test with stored embeddings
        local chunks = embedding.find_relevant_chunks(embedding1, 3)
        vim.notify(string.format("Found %d chunks from stored embeddings", #chunks), vim.log.levels.INFO)
      end)
    end)
  end, { desc = "Debug similarity calculation" })

  vim.api.nvim_create_user_command("FluxTestSimpleQuery", function()
    local simple_llm = require("simple-llm")
    local embedding = require("embedding")
    
    vim.notify("Testing simple query with stored embeddings...", vim.log.levels.INFO)
    
    -- First, test if embeddings are loading correctly
    local embeddings_data = embedding.load_embeddings()
    if not embeddings_data then
      vim.notify("Failed to load embeddings data", vim.log.levels.ERROR)
      return
    end
    
    vim.notify("Embeddings data loaded successfully", vim.log.levels.INFO)
    
    -- Test with a very simple query that should match the stored content
    simple_llm.ask_embedding("calculator", function(query_embedding, err)
      if err then
        vim.notify("Failed to generate query embedding: " .. err, vim.log.levels.ERROR)
        return
      end
      
      if not query_embedding then
        vim.notify("Query embedding is nil", vim.log.levels.ERROR)
        return
      end
      
      vim.notify(string.format("Query embedding generated: %d dimensions", #query_embedding), vim.log.levels.INFO)
      
      -- Debug: Check if query embedding has valid values
      local has_valid_values = false
      local first_few_values = {}
      for i = 1, math.min(5, #query_embedding) do
        table.insert(first_few_values, query_embedding[i])
        if query_embedding[i] ~= 0 and query_embedding[i] ~= nil then
          has_valid_values = true
        end
      end
      vim.notify("Query embedding has valid non-zero values: " .. tostring(has_valid_values), vim.log.levels.INFO)
      vim.notify("First few values: " .. table.concat(first_few_values, ", "), vim.log.levels.INFO)
      
      local chunks = embedding.find_relevant_chunks(query_embedding, 3)
      if #chunks > 0 then
        vim.notify(string.format("Found %d relevant chunks:", #chunks), vim.log.levels.INFO)
        for i, chunk in ipairs(chunks) do
          local relative_path = vim.fn.fnamemodify(chunk.file_path, ":.")
          vim.notify(string.format("  Chunk %d: %s (similarity: %.6f)", i, relative_path, chunk.similarity), vim.log.levels.INFO)
        end
      else
        vim.notify("No chunks found with simple query 'calculator'", vim.log.levels.WARN)
        vim.notify("This suggests a bug in similarity calculation or embedding comparison", vim.log.levels.ERROR)
      end
    end)
  end, { desc = "Test simple query with stored embeddings" })

  vim.api.nvim_create_user_command("FluxListEmbeddingModels", function()
    local config = require("flux").config
    local url = string.format("http://%s:%d/v1/models", config.embedding.host, config.embedding.port)
    local curl_cmd = string.format("curl -s %s", url)
    
    vim.notify("Fetching available embedding models...", vim.log.levels.INFO)
    
    vim.fn.jobstart(curl_cmd, {
      on_stdout = function(_, data)
        if data and #data > 0 then
          local response = table.concat(data, "")
          local ok, json = pcall(vim.json.decode, response)
          if ok and json and json.data then
            vim.notify("Available embedding models:", vim.log.levels.INFO)
            for _, model in ipairs(json.data) do
              vim.notify(string.format("  - %s", model.id), vim.log.levels.INFO)
            end
          else
            vim.notify("Failed to parse models response: " .. response:sub(1, 100), vim.log.levels.ERROR)
          end
        end
      end,
      on_stderr = function(_, data)
        if data and #data > 0 then
          vim.notify("Error fetching models: " .. table.concat(data, "\n"), vim.log.levels.ERROR)
        end
      end,
      on_exit = function(_, exit_code)
        if exit_code ~= 0 then
          vim.notify("Failed to fetch models (exit code: " .. exit_code .. ")", vim.log.levels.ERROR)
        end
      end
    })
  end, { desc = "List available embedding models" })

  vim.api.nvim_create_user_command("FluxCheckEmbeddingServer", function()
    local config = require("flux").config
    
    vim.notify("Checking embedding server status...", vim.log.levels.INFO)
    vim.notify(string.format("Server: %s:%d", config.embedding.host, config.embedding.port), vim.log.levels.INFO)
    
    -- Test basic connectivity
    local test_url = string.format("http://%s:%d/", config.embedding.host, config.embedding.port)
    local curl_cmd = string.format("curl -s -I %s", test_url)
    
    vim.fn.jobstart(curl_cmd, {
      on_stdout = function(_, data)
        if data and #data > 0 then
          vim.notify("Server is responding:", vim.log.levels.INFO)
          for _, line in ipairs(data) do
            if line ~= "" then
              vim.notify("  " .. line, vim.log.levels.INFO)
            end
          end
        end
      end,
      on_stderr = function(_, data)
        if data and #data > 0 then
          vim.notify("Server error: " .. table.concat(data, "\n"), vim.log.levels.ERROR)
        end
      end,
      on_exit = function(_, exit_code)
        if exit_code == 0 then
          vim.notify("Embedding server is reachable", vim.log.levels.INFO)
        else
          vim.notify("Embedding server is not reachable (exit code: " .. exit_code .. ")", vim.log.levels.ERROR)
          vim.notify("Make sure your embedding model is running on port " .. config.embedding.port, vim.log.levels.WARN)
        end
      end
    })
  end, { desc = "Check if embedding server is reachable" })

  vim.api.nvim_create_user_command("FluxTestRawEmbedding", function()
    local config = require("flux").config
    
    vim.notify("Testing raw embedding server response...", vim.log.levels.INFO)
    
    -- Create a simple test payload
    local payload = {
      model = config.embedding.model,
      input = "test"
    }
    
    local temp_file = vim.fn.tempname()
    local file = io.open(temp_file, "w")
    if file then
      file:write(vim.json.encode(payload))
      file:close()
      
      local url = string.format("http://%s:%d/v1/embeddings", config.embedding.host, config.embedding.port)
      local curl_cmd = string.format('curl -s %s -H "Content-Type: application/json" -d @%s', url, temp_file)
      
      vim.fn.jobstart(curl_cmd, {
        on_stdout = function(_, data)
          if data and #data > 0 then
            local response = table.concat(data, "")
            vim.notify("Raw embedding response:", vim.log.levels.INFO)
            vim.notify(response:sub(1, 500) .. "...", vim.log.levels.INFO)
            
            -- Try to parse the response
            local ok, json = pcall(vim.json.decode, response)
            if ok and json and json.data and #json.data > 0 and json.data[1].embedding then
              local embedding = json.data[1].embedding
              vim.notify(string.format("Successfully parsed embedding: %d dimensions", #embedding), vim.log.levels.INFO)
              vim.notify("First few values: " .. table.concat({embedding[1], embedding[2], embedding[3]}, ", "), vim.log.levels.INFO)
            else
              vim.notify("Failed to parse embedding from response", vim.log.levels.ERROR)
            end
          end
        end,
        on_stderr = function(_, data)
          if data and #data > 0 then
            vim.notify("Raw embedding error: " .. table.concat(data, "\n"), vim.log.levels.ERROR)
          end
        end,
        on_exit = function(_, exit_code)
          vim.fn.delete(temp_file)
          if exit_code ~= 0 then
            vim.notify("Raw embedding request failed (exit code: " .. exit_code .. ")", vim.log.levels.ERROR)
          end
        end
      })
    else
      vim.notify("Failed to create temp file for embedding test", vim.log.levels.ERROR)
    end
  end, { desc = "Test raw embedding server response" })

  vim.notify("🤖 Flux.nvim Agent is ready to think with you!", vim.log.levels.INFO)
end

-- Export main functions for backward compatibility and external access
M.create_chat_interface = require("chat").create_interface
M.toggle = require("chat").toggle

return M
