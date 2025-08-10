-- Flux.nvim plugin initialization
-- This file is automatically loaded by Neovim when the plugin is installed

if vim.g.loaded_flux then
  return
end
vim.g.loaded_flux = 1

-- Setup Flux.nvim
local function setup_flux()
  local ok, flux = pcall(require, "flux")
  if not ok then
    vim.notify("Flux.nvim: Failed to load plugin", vim.log.levels.ERROR)
    return
  end
  
  flux.setup()
end

-- Setup simple-llm core
local function setup_simple_llm()
  local ok, simple_llm = pcall(require, "simple-llm")
  if not ok then
    vim.notify("Flux.nvim: Failed to load simple-llm core", vim.log.levels.ERROR)
    return
  end
  
  simple_llm.setup()
end

-- Initialize plugin
vim.defer_fn(function()
  setup_flux()
  setup_simple_llm()
end, 0)

-- Create user commands
vim.api.nvim_create_user_command("FluxChat", function()
  require("flux").create_chat_interface()
end, { desc = "Open Flux chat interface" })

vim.api.nvim_create_user_command("FluxToggle", function()
  require("flux").toggle()
end, { desc = "Toggle Flux chat interface" })

vim.api.nvim_create_user_command("FluxCompletion", function(opts)
  local flux_completion = require("flux.completion")
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