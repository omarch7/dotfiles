# Omar's Dotfiles

This repository contains my personal dotfiles, with a primary focus on my Neovim configuration.

## Neovim Configuration

My Neovim setup is designed to be modular, performant, and feature-rich. It uses [lazy.nvim](https://github.com/folke/lazy.nvim) as the plugin manager.

### Structure
```
nvim/
├── init.lua              # Main entry point
├── lazy-lock.json        # Plugin version lock file
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
- **Treesitter**: Advanced syntax highlighting and code navigation
- **Telescope**: Fuzzy finder for files, buffers, and more
- **Git Integration**: Seamless Git workflow within the editor
- **AI Assistance**: LLM integration for coding assistance

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
