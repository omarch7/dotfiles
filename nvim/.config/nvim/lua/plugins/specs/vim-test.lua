return {
    {
        "vim-test/vim-test",
        init = function()
            vim.g["test#python#pytest#executable"] = "uv run pytest"
        end,
    },
}
