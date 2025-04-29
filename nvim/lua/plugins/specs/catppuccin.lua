return {
    {
        "catppuccin/nvim",
        name = "catppuccin",
        priority = 1000,
        config = function()
            require("catppuccin").setup {
                cmp = true,
                treesitter = true,
                diffview = true,
            }
        end,
    },
}
