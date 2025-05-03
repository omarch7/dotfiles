return {
    { "tpope/vim-fugitive" },
    { "tpope/vim-rhubarb" },
    { 'f-person/git-blame.nvim' },
    {
        "sindrets/diffview.nvim",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function()
            require("diffview").setup({})
        end,
    }
}
