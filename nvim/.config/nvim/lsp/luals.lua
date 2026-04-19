return {
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
}
