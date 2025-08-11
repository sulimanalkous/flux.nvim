-- Flux.nvim plugin initialization
-- This file is automatically loaded by Neovim when the plugin is installed

if vim.g.loaded_flux then
  return
end
vim.g.loaded_flux = 1

-- Create user commands
-- The require calls here are safe because they only run when the user executes the command,
-- by which time the plugin will have been fully loaded and configured by lazy.nvim.
vim.api.nvim_create_user_command("FluxChat", function()
  local chat = require("chat")
  chat.create_interface()
end, { desc = "Open Flux chat interface" })

vim.api.nvim_create_user_command("FluxToggle", function()
  local chat = require("chat")
  chat.toggle()
end, { desc = "Toggle Flux chat interface" })

vim.api.nvim_create_user_command("FluxCompletion", function(opts)
  local flux_completion = require("completion")
  if opts.args == "toggle" then
    flux_completion.state.enabled = not flux_completion.state.enabled
    local status = flux_completion.state.enabled and "enabled" or "disabled"
    vim.notify("Flux completion " .. status, vim.log.levels.INFO)
  elseif opts.args == "trigger" then
    flux_completion.trigger_completion()
  else
    vim.notify("Usage: :FluxCompletion toggle|trigger", vim.log.levels.WARN)
  end
end, {
  desc = "Control Flux completion",
  nargs = 1,
  complete = function()
    return {"toggle", "trigger"}
  end
})

vim.api.nvim_create_user_command("FluxModel", function(opts)
  local simple_llm = require("simple-llm")
  if opts.args == "detect" then
    simple_llm.reset_model_detection()
    simple_llm.detect_model_type()
  elseif opts.args == "reset" then
    simple_llm.reset_model_detection()
  elseif opts.args == "status" then
    local model_type = simple_llm.detect_model_type()
    local config = simple_llm.get_model_config()
    vim.notify("Current model: " .. model_type .. "\nConfig: " .. vim.inspect(config), vim.log.levels.INFO)
  else
    vim.notify("Usage: :FluxModel detect|reset|status", vim.log.levels.WARN)
  end
end, {
  desc = "Manage Flux model detection",
  nargs = 1,
  complete = function()
    return {"detect", "reset", "status"}
  end
})

vim.api.nvim_create_user_command("FluxIndexProject", function()
  local project_index = require("tools").get_tool("project_index")
  project_index.index_project()
end, { desc = "Index project files for RAG" })
