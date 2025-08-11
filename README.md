# 🤖 Flux.nvim

> *Your intelligent AI coding partner*

A thinking, reasoning AI coding assistant that works with you like a helpful colleague. Built for developers who want an AI partner that can think, plan, debug, and code alongside them - not just complete code.

## ✨ Features

### 🧠 **Intelligent Agent**
- **Thinking Partner**: Reason step-by-step, explain your approach, work through problems together
- **Natural Conversation**: Chat like you're talking to a helpful colleague
- **Context Awareness**: Understands your entire project and conversation history
- **Proactive Suggestions**: Suggests improvements and next steps

### 💬 **Smart Chat Interface**
- Natural conversation with deep reasoning capabilities
- File editing directly from chat: *"Let's fix this code together"* → AI thinks through the problem and implements the solution
- File operations: *"Read docs/"*, *"Show me config.lua"*
- Beautiful markdown interface with real-time streaming responses

### 🤖 **Copilot-Style Completion**
- Real-time code suggestions as you type
- Tab to accept, Ctrl+Space to trigger manually
- Non-blocking, async operations - never freezes Neovim
- Performance optimized for 500ms average latency

### ✏️ **Interactive Code Editing**
- Chat-based editing with instant buffer updates
- Interactive edit mode with before/after preview
- Multiple editing workflows for different needs

### 📁 **File Operations**
- Read any file or directory from chat
- Context-aware suggestions based on current file
- Browse project structure conversationally

## 🚀 Quick Start

### Prerequisites
- Neovim >= 0.8
- [llama-server](https://github.com/ggerganov/llama.cpp) or compatible LLM server running on `localhost:1234`
- Embedding model server on `localhost:1235` (optional, for enhanced context)
- Recommended model: Qwen2.5-Coder-7B-Instruct

### Installation

#### Using [lazy.nvim](https://github.com/folke/lazy.nvim)
```lua
{
  "sulimanalkous/flux.nvim",
  config = function()
    require("flux").setup({
      host = "localhost",
      port = 1234,
      embedding = {
        host = "localhost", 
        port = 1235,
      }
    })
  end,
}
```

#### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)
```lua
use {
  "sulimanalkous/flux.nvim",
  config = function()
    require("flux").setup({
      host = "localhost",
      port = 1234,
      embedding = {
        host = "localhost",
        port = 1235,
      }
    })
  end
}
```

#### Manual Installation
```bash
git clone https://github.com/sulimanalkous/flux.nvim.git ~/.local/share/nvim/site/pack/plugins/start/flux.nvim
```

### Setup Your LLM Server
```bash
# Start main model server
llama-server -m your-model.gguf --port 1234

# Start embedding model server (optional)
llama-server -m your-embedding-model.gguf --port 1235

# Or use Ollama
ollama serve
```

## 🎯 Usage

### Chat Interface
```lua
<leader>ac  -- Toggle chat interface
<leader>aa  -- Open chat interface  
<leader>la  -- Quick agent reasoning session
Ctrl+S      -- Send message (in chat)
q           -- Close chat
```

**Example conversations:**
- *"What do you think about this code structure?"* → AI analyzes and suggests improvements
- *"Help me debug this issue - I'm getting an error when..."* → AI thinks through the problem step-by-step
- *"Let's plan the architecture for this new feature"* → AI helps design and plan
- *"Can you explain how this algorithm works?"* → AI breaks it down and explains
- *"I'm stuck on this problem, can you help me think through it?"* → AI works with you to solve it

### Code Completion
```lua
Tab         -- Accept completion
Ctrl+Space  -- Trigger completion manually
<leader>tc  -- Toggle completion on/off
```

### Interactive Editing
```lua
<leader>ae  -- Edit selection with AI
<leader>af  -- Edit entire buffer with AI
<leader>lf  -- Quick fix code
<leader>le  -- Explain selected code
```

## 🏗️ Architecture

**Fast & Simple** - Just ~500 lines of clean Lua code

```
lua/
├── flux/
│   ├── init.lua         # Chat interface with @EDIT/@READ/@LIST
│   ├── edit.lua         # Interactive editing with preview  
│   └── completion.lua   # Async code completion
└── flux.lua       # Core LLM integration
```

### Key Design Principles
- ⚡ **Performance First** - Non-blocking async operations
- 🎯 **Zero Config** - Works out of the box
- 🔧 **Direct Control** - Simple, understandable codebase  
- 🚀 **Just Works** - No configuration hell

## 🛠️ Configuration

### Default Settings
```lua
require("flux").setup({
  completion = {
    enabled = true,
    debounce_delay = 2000,  -- 2 seconds
    max_tokens = 1024,
  },
  chat = {
    width_ratio = 0.4,      -- 40% of screen width
  },
  llm = {
    endpoint = "http://localhost:1234",
    temperature = 0.1,
  }
})
```

### Recommended Models
- **Qwen2.5-Coder-7B-Instruct** - Best coding performance
- DeepSeek-Coder-6.7B
- Phi-4 (3.8B) - Lighter option
- Mistral-7B-Instruct

## 📊 Performance

- **Completion latency**: ~500ms average
- **Chat response**: 1-3 seconds
- **Memory usage**: <50MB
- **No blocking**: UI stays responsive during all operations

## 🔧 Advanced Usage

### File Operations in Chat
```
You: Fix this code
AI:  I'll fix that for you.
     [✏️ Edited current file] ✅ test.py (42 lines)

You: Read docs/
AI:  [📁 Listing docs/]
     📄 README.md
     📄 setup.md
     📁 examples/
```

### Custom Commands
The AI understands these special commands:
- `@EDIT` - Edit current buffer
- `@READ path/to/file` - Read file content  
- `@LIST directory/` - List directory contents

## 🐛 Troubleshooting

### Common Issues

**Completion not working?**
- Check if llama-server is running on port 1234
- Try `<leader>tc` to toggle completion
- Verify model supports instruction following

**Chat freezing?**
- Restart Neovim
- Check llama-server logs
- Ensure sufficient memory for your model

**File operations failing?**
- Check file permissions
- Verify paths are correct
- Try absolute paths instead of relative

## 🗺️ Roadmap

### Version 1.1 (Next)
- [ ] Status indicators with fidget.nvim
- [ ] Visual diff view for edits
- [ ] Accept/reject interface for changes

### Version 1.2 (Future)
- [ ] Multi-model support
- [ ] Configuration system
- [ ] Performance optimizations

### Version 2.0 (Long-term)
- [ ] LSP integration
- [ ] Git workflow integration
- [ ] Plugin marketplace features

## 🤝 Contributing

Flux.nvim is built with simplicity in mind. Contributions should follow these principles:

- **Keep it simple** - Avoid unnecessary complexity
- **Performance first** - All operations should be async and fast  
- **Minimal dependencies** - Pure Lua preferred
- **Clear code** - Self-documenting, well-commented

## 📄 License

MIT License - See [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

Built with inspiration from:
- [Avante.nvim](https://github.com/yetone/avante.nvim) - UI design concepts
- [CodeCompanion.nvim](https://github.com/olimorris/codecompanion.nvim) - Tool integration ideas
- [GitHub Copilot](https://github.com/features/copilot) - Completion UX patterns

**The difference?** Flux.nvim gives you the same power with 500 lines of code instead of thousands, and it just works without configuration hell.

---

<div align="center">

**🚀 Flux.nvim - Your coding flux, amplified**

*Fast. Simple. Powerful.*

[![MIT License](https://img.shields.io/badge/License-MIT-green.svg)](https://choosealicense.com/licenses/mit/)
[![Lua](https://img.shields.io/badge/Made%20with-Lua-blueviolet.svg)](https://lua.org)
[![Neovim](https://img.shields.io/badge/Made%20for-Neovim-green.svg)](https://neovim.io)

</div>
