return {
    {
        "catppuccin/nvim",
        name = "catppuccin",
        priority = 1000,
        config = function()
            require("catppuccin").setup {
                flavour = "auto",
                background = {
                    light = "latte",
                    dark = "mocha",
                },
                integrations = {
                    blink_cmp = true,
                    treesitter = true,
                    diffview = true,
                    gitsigns = true,
                    fzf = true,
                    lualine = true,
                    dap_ui = true,
                    dap = true,
                    render_markdown = true,
                    snacks = {
                        enabled = true,
                    },
                    telescope = {
                        enabled = true,
                    },
                    which_key = true,
                },
            }
        end,
    },
}
