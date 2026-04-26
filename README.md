# Omar's Dotfiles

This repository contains my personal dotfiles, including configurations for Neovim and tmux designed for a productive development environment.

## Neovim Configuration

My Neovim setup is designed to be modular, performant, and feature-rich. It uses [lazy.nvim](https://github.com/folke/lazy.nvim) as the plugin manager.

### Structure

Files live inside a stow package (`nvim/.config/nvim/`) so they map to `~/.config/nvim/` when stowed.

```
nvim/.config/nvim/
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
            ├── auto-dark-mode.lua  # Auto light/dark mode switcher
            ├── blink.lua           # Completion engine
            ├── catppuccin.lua      # Colorscheme
            ├── comment.lua         # Comment utilities
            ├── conform.lua         # Code formatter
            ├── copilot.lua         # GitHub Copilot
            ├── dap-ui.lua          # Debug UI
            ├── dap.lua             # Debug adapter
            ├── fzf-lua.lua         # FZF integration
            ├── gitools.lua         # Git tools
            ├── gitsigns.lua        # Git signs
            ├── img-clip.lua        # Image clipboard
            ├── lspconfig.lua       # LSP configuration
            ├── lualine.lua         # Status line
            ├── mason.lua           # LSP/DAP installer
            ├── noice.lua           # Command/message UI
            ├── octo.lua            # GitHub PRs & issues
            ├── render-markdown.lua # Markdown rendering
            ├── snacks.lua          # Snacks.nvim utilities
            ├── telescope.lua       # Fuzzy finder
            ├── treesitter.lua      # Syntax highlighting
            ├── ufo.lua             # Folding
            ├── vim-bookmarks.lua   # Bookmarks
            ├── vim-test.lua        # Testing
            ├── vim-tmux-navigator.lua  # Tmux integration
            └── which-key.lua       # Key helper
```

### Key Features

- **Modular Organization**: Configuration is split into logical components
- **Lazy Loading**: Plugins are loaded only when needed for faster startup
- **LSP Integration**: Full Language Server Protocol support via Mason and lspconfig
- **Treesitter**: Enhanced syntax highlighting and code navigation with support for lua, python, rust, yaml, sql, toml and more
- **Snacks.nvim**: Modern UI toolkit providing file picker, explorer, terminal, Git integration, and more
- **Blink.cmp**: Fast completion engine with LSP, path, snippets, and buffer sources
- **Formatting**: conform.nvim for fast, async code formatting across languages
- **Code Folding**: nvim-ufo for smart folding with LSP and indent providers
- **Git Integration**: Seamless Git workflow with Gitsigns, DiffView, Snacks Git Browse/LazyGit, and Octo for GitHub PRs/issues
- **Modern UI**: Noice.nvim for cleaner cmdline, messages, and notifications
- **Theme Awareness**: Auto Dark Mode switches between light/dark variants with the system
- **AI Assistance**: GitHub Copilot for AI-powered code suggestions
- **Debugging**: DAP (Debug Adapter Protocol) integration with rich UI and extensive keymappings
- **Testing**: vim-test integration with custom keybindings for various test workflows
- **Tmux Integration**: Seamless navigation between Neovim and tmux panes

### Notable Plugins

- **UI & Appearance**
  - **Catppuccin**: Modern colorscheme with Treesitter and completion support
  - **Auto Dark Mode**: Follows the system's light/dark preference
  - **Lualine**: Customized status line with time display and modern separators
  - **Noice.nvim**: Replaces the default cmdline, messages, and popupmenu UI
  - **Snacks.nvim**: Dashboard, notifications, and modern UI components
  - **render-markdown.nvim**: Pretty in-buffer Markdown rendering

- **Editor Enhancements**
  - **Blink.cmp**: Advanced completion with intelligent delays and cmdline support
  - **conform.nvim**: Async, multi-language code formatting
  - **nvim-ufo**: Smart code folding with LSP integration
  - **vim-tmux-navigator**: Seamless tmux/Neovim pane navigation
  - **Comment.nvim**: Easy code commenting
  - **vim-bookmarks**: Persistent file bookmarks
  - **which-key.nvim**: Discoverable keybinding hints
  - **img-clip.nvim**: Paste images from the clipboard into Markdown/notes

- **Development Tools**
  - **Mason**: Automatic LSP/DAP server installation
  - **nvim-lspconfig**: LSP configuration for multiple languages
  - **Snacks Picker**: Fast file finding and grep with hidden file support
  - **fzf-lua**: Powerful fzf-based pickers
  - **Telescope**: Extensible fuzzy finder for additional workflows

- **Git Tools**
  - **Gitsigns**: Inline git status, hunk preview, and reset
  - **DiffView**: Visual diff comparison and file history
  - **Snacks Git**: Git browse and LazyGit integration
  - **Octo.nvim**: Review and manage GitHub PRs and issues from Neovim

- **AI Integration**
  - **GitHub Copilot**: AI-powered code suggestions

### Key Keybindings

**Note**: Leader key is set to `<Space>`

#### LSP & Editing
- `<leader>F`: Format code
- `<leader>rn`: Rename symbol
- `<leader>ca`: Code action
- `<leader>K`: Hover documentation
- `<leader>fb`: Go to definition

#### File Navigation (Snacks)
- `<leader><leader>`: Smart picker (context-aware)
- `<leader>ff`: Find files
- `<leader>fg`: Grep text in files
- `<leader>fr`: LSP references
- `<leader>e`: Toggle file explorer
- `<leader>sd`: Show diagnostics (workspace)
- `<leader>sD`: Show diagnostics (buffer)

#### Git (Snacks & Gitsigns)
- `<leader>gg`: LazyGit integration
- `<leader>gB`: Git browse (open in browser)
- `<leader>gp`: Preview hunk
- `<leader>gr`: Reset hunk
- `[c`: Previous hunk
- `]c`: Next hunk

#### DiffView
- `<leader>gvm`: DiffView against master
- `<leader>gv1`: DiffView against HEAD~1
- `<leader>gv2`: DiffView against HEAD~2
- `<leader>gvc`: Close DiffView
- `<leader>gvh`: File history

#### Terminal
- `<C-/>`: Toggle terminal

#### Testing
- `<leader>tf`: Run test file
- `<leader>ts`: Run test suite
- `<leader>tn`: Run nearest test
- `<leader>tl`: Run last test

#### Debugging (DAP)
- `<leader>dd`: Start/continue debugging
- `<leader>dt`: Terminate debugging session
- `<leader>db`: Toggle breakpoint
- `<leader>do`: Step over
- `<leader>du`: Step out
- `<leader>di`: Step into
- `<leader>de`: Open REPL
- `<leader>dui`: Toggle DAP UI
- `<leader>due`: Evaluate expression

#### Code Folding
- `zR`: Open all folds
- `zM`: Close all folds

#### Tmux Navigation
- `<C-h>`: Navigate left (works in both Neovim and tmux)
- `<C-j>`: Navigate down
- `<C-k>`: Navigate up
- `<C-l>`: Navigate right
- `<C-\>`: Navigate to previous pane

## Tmux Configuration

My tmux setup is designed for seamless integration with Neovim and features a modern, visually appealing interface.

### Key Features

- **Prefix Key**: `<C-s>` (Control + s) for all tmux commands
- **Mouse Support**: Disabled for keyboard-focused workflow
- **Vi Mode**: Vi-style key bindings in copy mode
- **True Color Support**: 256-color terminal with RGB support
- **Top Status Bar**: Status bar positioned at the top
- **Catppuccin Mocha Theme**: Matching Neovim colorscheme for visual consistency

### Plugins (via TPM)

- **tmux-sensible**: Sensible default settings
- **vim-tmux-navigator**: Seamless navigation between tmux and Neovim panes
- **tmux-fzf-url**: FZF-based URL picker
- **tmux-cpu**: CPU usage monitoring
- **tmux-battery**: Battery status display
- **catppuccin/tmux**: Beautiful Catppuccin Mocha theme

### Status Bar Modules

The status bar includes:
- Application name
- CPU usage
- Session name
- System uptime
- Battery status

### Key Bindings

- `<C-s>r`: Reload tmux configuration
- `<C-s>h`: Select left pane
- `<C-s>j`: Select down pane
- `<C-s>k`: Select up pane
- `<C-s>l`: Select right pane

**Note**: When used with vim-tmux-navigator, `<C-h/j/k/l>` navigates seamlessly between tmux panes and Neovim splits.

## Installation

This repository is organized as a [GNU Stow](https://www.gnu.org/software/stow/) package layout. Each top-level directory (`nvim`, `tmux`) mirrors the file tree that should appear in `$HOME`, so `stow` will create the appropriate symlinks for you.

1. Install GNU Stow:
   ```bash
   # Arch
   sudo pacman -S stow

   # Debian/Ubuntu
   sudo apt install stow

   # macOS
   brew install stow
   ```

2. Clone this repository into your home directory:
   ```bash
   gh repo clone omarch7/dotfiles ~/.dotfiles
   ```

3. Stow the configurations from inside the repository:
   ```bash
   cd ~/.dotfiles

   # Neovim configuration → ~/.config/nvim
   stow nvim

   # Tmux configuration → ~/.tmux.conf and ~/.tmux/
   stow tmux
   ```

   To remove the symlinks later, run `stow -D <package>` from the same directory.

4. Install Neovim plugins:
   - Launch Neovim, and lazy.nvim will automatically install all configured plugins

5. Install tmux plugins (optional):
   ```bash
   # Install TPM (Tmux Plugin Manager)
   git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

   # Launch tmux and press <C-s>I (Control+s then Shift+i) to install plugins
   ```

## Customization

Feel free to fork this repository and customize it to your needs. The modular structure makes it easy to add, remove, or modify components.

## License

This project is open source and available under the [MIT License](LICENSE).
