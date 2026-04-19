return {
    {
        "neovim/nvim-lspconfig",
        dependencies = {
            "williamboman/mason.nvim",           -- Package manager for LSP servers
            "williamboman/mason-lspconfig.nvim", -- Integration between Mason and nvim-lspconfig
        },
    }
}
