return {
    {
        "nvim-treesitter/nvim-treesitter",
        branch = "main",
        build = ":TSInstall lua python rust yaml sql toml markdown markdown_inline html",
        opts = {},
    }
}
