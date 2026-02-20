return {
    {
        "williamboman/mason.nvim",
        config = function()
            require("mason").setup({
                ui = {
                    icons = {
                        -- Using more reliable Nerd Font icons
                        package_installed = "✓",  -- Simple checkmark
                        package_pending = "➜",    -- Arrow
                        package_uninstalled = "✗", -- X mark
                    },
                }
            })
        end,
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
                    "ts_ls",
                },
                automatic_installation = true,
            })
        end
    },
}
