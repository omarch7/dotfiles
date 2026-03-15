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
                    cmp = true,
                    treesitter = true,
                    diffview = true,
                    gitsigns = true,
                    notify = true,
                    dashboard = true,
                    fzf = true,
                    lualine = true,
                    dap_ui = true,
                    dap = true,
                    render_markdown = true,
                    snacks = {
                        enabled = true,
                    },
                    telescope = true,
                    which_key = true,

                },
            }
        end,
    },
}
