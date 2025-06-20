# Omar's Dotfiles

This repository contains my personal dotfiles, with a primary focus on my Neovim configuration.

## Neovim Configuration

My Neovim setup is designed to be modular, performant, and feature-rich. It uses [lazy.nvim](https://github.com/folke/lazy.nvim) as the plugin manager.

### Structure
```
nvim/
├── init.lua              # Main entry point
├── lazy-lock.json        # Plugin version lock file
├── lsp/                 # Language Server Protocol configurations
└── lua/
    ├── core/             # Core configuration
    │   ├── autocmds.lua  # Autocommands
    │   ├── keymaps.lua   # Key mappings
    │   └── options.lua   # Neovim options
    └── plugins/          # Plugin configuration
        ├── init.lua      # Plugin loader
        └── specs/        # Plugin specifications
            ├── coding.lua
            ├── colorscheme.lua
            ├── completion.lua
            ├── editor.lua
            ├── git.lua
            ├── lang.lua
            ├── linting.lua
            ├── llm.lua
            ├── lsp.lua
            ├── telescope.lua
            ├── treesitter.lua
            └── ui.lua
```

### Key Features

- **Modular Organization**: Configuration is split into logical components
- **Lazy Loading**: Plugins are loaded only when needed for faster startup
- **LSP Integration**: Full Language Server Protocol support
- **Treesitter**: Enhanced syntax highlighting and code navigation with support for lua, python, rust, yaml, sql, toml and more
- **Telescope**: Fuzzy finder for files, buffers, and more
- **Git Integration**: Seamless Git workflow with DiffView and Gitsigns
- **AI Assistance**: LLM integration for coding assistance with multiple providers
- **Debugging**: DAP (Debug Adapter Protocol) integration with UI and extensive keymappings
- **Testing**: vim-test integration with custom keybindings for various test workflows
- **Navigation**: NvimTree for file browsing and project management

### Notable Plugins

- **UI & Appearance**
  - Status line, bufferline, and various UI enhancements
  - Custom colorscheme configuration

- **Editor Enhancements**
  - Advanced text editing capabilities
  - Navigation and window management tools

- **Development Tools**
  - LSP configuration for multiple languages
  - Linting and formatting integrations
  - Completion engine with snippets

- **Git Tools**
  - Git signs, diff views, and commit integration

- **AI & LLM Integration**
  - AI-assisted coding and completion

### Key Keybindings

- `<C-n>`: Toggle NvimTree file explorer
- `<leader>F`: Format code
- `<leader>rn`: Rename symbol (LSP)
- `<leader>ca`: Code action (LSP)
- `<leader>ff`: Find files (Telescope)
- `<leader>fg`: Find text in files (Telescope grep)

#### Testing
- `<leader>tf`: Run test file
- `<leader>ts`: Run test suite
- `<leader>tn`: Run nearest test
- `<leader>tl`: Run last test

#### Debugging
- `<leader>dd`: Start/continue debugging
- `<leader>dt`: Terminate debugging session
- `<leader>db`: Toggle breakpoint

## LLM Configuration

My setup includes configuration for multiple LLM providers through the Avante.nvim plugin:

- **Claude via Anthropic API**: Direct integration with Claude models
- **Claude via AWS Bedrock**: Integration through AWS Bedrock service
- **Ollama with Qwen model**: Local LLM support
- **Google Gemini**: Integration with Google's Gemini models

Configuration settings are maintained in `lua/plugins/specs/avante.lua`.

## Installation

1. Clone this repository:
   ```bash
   gh repo clone omarch7/dotfiles ~/.dotfiles
   ```

2. Create symbolic links:
   ```bash
   ln -s ~/.dotfiles/nvim ~/.config/nvim
   ```

3. Launch Neovim, and the plugin manager will automatically install all plugins.

## Customization

Feel free to fork this repository and customize it to your needs. The modular structure makes it easy to add, remove, or modify components.

## License

This project is open source and available under the [MIT License](LICENSE).
