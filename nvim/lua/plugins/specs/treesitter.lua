return {
    {
        "nvim-treesitter/nvim-treesitter",
        build = ":TSUpdate",     -- Automatically update parsers
        config = function()
            require("nvim-treesitter.configs").setup({
                ensure_installed = { "lua", "python", "rust", "yaml", "sql", "toml" },     -- Add your preferred languages
                sync_install = false,                                                      -- Install languages asynchronously
                auto_install = true,                                                       -- Automatically install missing parsers
                highlight = {
                    enable = true,                                                         -- Enable syntax highlighting
                    additional_vim_regex_highlighting = false,                             -- Use only Tree-sitter for highlighting
                },
                indent = {
                    enable = true,     -- Enable improved indentation
                },
                modules = {},
                ignore_install = {},
            })
        end,
    }
}
