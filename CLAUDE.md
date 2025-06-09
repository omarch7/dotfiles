# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This repository contains custom dotfiles, primarily focusing on a Neovim configuration. The Neovim setup is designed to be modular, performant, and feature-rich with a wide range of plugins for development workflows.

## Installation & Setup

1. Installation is done by creating symbolic links:
   ```bash
   ln -s ~/.dotfiles/nvim ~/.config/nvim
   ```

2. When launching Neovim for the first time, lazy.nvim will automatically install all configured plugins.

## Repository Structure

The repository follows a clean, modular structure:

- `nvim/`: Main Neovim configuration
  - `init.lua`: Entry point that loads core modules and plugins
  - `lua/core/`: Core Neovim configuration (options, keymaps, autocmds)
  - `lua/plugins/`: Plugin management and configuration
    - `specs/`: Individual plugin specifications
  - `lsp/`: Language Server Protocol configurations

## Key Components & Architecture

### Plugin Management

The configuration uses lazy.nvim for efficient plugin management with lazy loading capabilities. Plugins are organized into modular specification files in `lua/plugins/specs/`.

### Core Features

1. **LSP Integration**: Complete Language Server Protocol support configured in `lspconfig.lua`

2. **Treesitter**: Enhanced syntax highlighting and code navigation with supported languages:
   - lua, python, rust, yaml, sql, toml

3. **AI & LLM Integration**: 
   - GitHub Copilot integration with custom keybindings
   - Avante.nvim for LLM assistance with multiple provider options (Bedrock, Claude, Ollama, Gemini)

4. **Debugging**: 
   - DAP (Debug Adapter Protocol) integration with UI
   - Extensive keymappings for debugging workflows

5. **Testing**: 
   - vim-test integration with keymaps for running tests

6. **Git Integration**:
   - DiffView for visual diff comparisons
   - Gitsigns for inline git status indicators

7. **Navigation & Productivity**:
   - Telescope for fuzzy finding and navigation
   - NvimTree for file browsing

### Key Keybindings

- `<C-n>`: Toggle NvimTree file explorer
- `<leader>F`: Format code
- `<leader>rn`: Rename symbol (LSP)
- `<leader>ca`: Code action (LSP)
- `<leader>ff`: Find files (Telescope)
- `<leader>fg`: Find text in files (Telescope grep)
- `<leader>tf`: Run test file
- `<leader>ts`: Run test suite
- `<leader>tn`: Run nearest test
- `<leader>tl`: Run last test
- `<leader>dd`: Start/continue debugging
- `<leader>dt`: Terminate debugging session
- `<leader>db`: Toggle breakpoint

## LLM Configuration

The repository includes configuration for multiple LLM providers in the Avante plugin:

- Claude via Anthropic API
- Claude via AWS Bedrock
- Ollama with Qwen model
- Google Gemini

Each provider has specific configuration settings in `lua/plugins/specs/avante.lua`.