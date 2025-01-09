vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

vim.cmd([[
    set number
    syntax on
]])

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
    local lazyrepo = "https://github.com/folke/lazy.nvim.git"
    local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
    if vim.v.shell_error ~= 0 then
        vim.api.nvim_echo({
            { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
            { out,                            "WarningMsg" },
            { "\nPress any key to exit..." },
        }, true, {})
        vim.fn.getchar()
        os.exit(1)
    end
end
vim.opt.rtp:prepend(lazypath)

-- Make sure to setup `mapleader` and `maplocalleader` before
-- loading lazy.nvim so that mappings are correct.
-- This is also a good place to setup other settings (vim.opt)
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Setup lazy.nvim
require("lazy").setup({
    spec = {
        {
            "nvim-tree/nvim-tree.lua",
            dependencies = { "nvim-tree/nvim-web-devicons" },
            config = function()
                require("nvim-tree").setup()
            end,
        },
        { "nvim-tree/nvim-web-devicons" },
        {
            "nvim-treesitter/nvim-treesitter",
            build = ":TSUpdate", -- Automatically update parsers
            config = function()
                require("nvim-treesitter.configs").setup({
                    ensure_installed = { "lua", "python", "rust", "yaml", "sql", "toml" }, -- Add your preferred languages
                    sync_install = false,                                                  -- Install languages asynchronously
                    auto_install = true,                                                   -- Automatically install missing parsers
                    highlight = {
                        enable = true,                                                     -- Enable syntax highlighting
                        additional_vim_regex_highlighting = false,                         -- Use only Tree-sitter for highlighting
                    },
                    indent = {
                        enable = true, -- Enable improved indentation
                    },
                })
            end,
        },
        { "williamboman/mason.nvim",          config = true },
        { "williamboman/mason-lspconfig.nvim" },
        { "neovim/nvim-lspconfig" },
        { "github/copilot.vim" },
        { "airblade/vim-gitgutter" },
        { "tpope/vim-fugitive" },
        { "tpope/vim-rhubarb" },
        { 'f-person/git-blame.nvim' },
        { 'nvim-telescope/telescope.nvim',    tag = '0.1.8', dependencies = { 'nvim-lua/plenary.nvim' } },
        {
            'maxmx03/fluoromachine.nvim',
            lazy = false,
            priority = 1000,
            config = function()
                local fm = require('fluoromachine')

                fm.setup {
                    glow = true,
                    theme = 'fluoromachine',
                    transparent = true,
                }
                vim.cmd('colorscheme fluoromachine')
                vim.opt.termguicolors = true
            end
        },
        {
            "folke/which-key.nvim",
            event = "VeryLazy",
            opts = {
                -- your configuration comes here
                -- or leave it empty to use the default settings
                -- refer to the configuration section below
            },
            keys = {
                {
                    "<leader>?",
                    function()
                        require("which-key").show({ global = false })
                    end,
                    desc = "Buffer Local Keymaps (which-key)",
                },
            },
        },
        { 'mfussenegger/nvim-dap' },
    },
})

vim.api.nvim_create_autocmd({ "VimEnter" }, {
    callback = function()
        if vim.fn.argc() == 0 then
            require("nvim-tree.api").tree.open()
        end
    end,
})

vim.api.nvim_create_autocmd("BufEnter", {
    nested = true,
    callback = function()
        local tree_wins = {}
        local normal_wins = {}

        for _, win in ipairs(vim.api.nvim_list_wins()) do
            local bufname = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win))
            if bufname:match("NvimTree_") then
                table.insert(tree_wins, win)
            else
                table.insert(normal_wins, win)
            end
        end

        if #normal_wins == 0 then
            vim.cmd("quit")
        end
    end,
})

vim.keymap.set("n", "<C-n>", ":NvimTreeToggle<CR>", { noremap = true, silent = true })

vim.keymap.set("n", "<leader>f", function()
    vim.lsp.buf.format({ async = true })
end, { noremap = true, silent = true })

vim.keymap.set("n", "<leader>gd", "<cmd>Telescope lsp_definitions<CR>", { noremap = true, silent = true })

local builtin = require("telescope.builtin")
vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Telescope find files" })
vim.keymap.set("n", "<leader>fg", builtin.live_grep, { desc = "Telescope find inside files" })

require("mason-lspconfig").setup({
    ensure_installed = {
        "lua_ls",
        "rust_analyzer",
        "pylsp",
        "gopls",
    },
    automatic_installation = true,
})

local lspconfig = require("lspconfig")
-- Lua
lspconfig.lua_ls.setup({
    settings = {
        Lua = {
            diagnostics = {
                globals = { "vim" },
            },
            format = {
                enable = true,
            },
            workspace = {
                library = vim.api.nvim_get_runtime_file("", true),
                checkThirdParty = false,
            },
        },
    },
})
-- Rust
lspconfig.rust_analyzer.setup({})
-- Python
lspconfig.pylsp.setup({
    settings = {
        pylsp = {
            plugins = {
                pylint = {
                    maxLineLength = 120,
                },
                pycodestyle = {
                    maxLineLength = 120,
                },
            },
        },
    },
})
-- Go
lspconfig.gopls.setup({})
