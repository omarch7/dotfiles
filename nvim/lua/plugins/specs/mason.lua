return {
    {
        "williamboman/mason.nvim", config = true
    },
    {
        "williamboman/mason-lspconfig.nvim",
        dependencies = {
            "williamboman/mason.nvim",
        },
        config = function()
            require("mason-lspconfig").setup({
                ensure_installed = {
                    "lua_ls",
                    "rust_analyzer",
                    "pylsp",
                    "gopls",
                    "jsonnet_ls",
                    "bashls",
                    "terraformls",
                    "yamlls",
                    "jsonls",
                },
                automatic_installation = true,
            })
        end
    },
}
