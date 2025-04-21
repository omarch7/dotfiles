return {
    {
        'numToStr/Comment.nvim',
        config = function()
            require("Comment").setup()
        end,
    },
    {
        "neovim/nvim-lspconfig",
        dependencies = {
            "williamboman/mason.nvim",           -- Package manager for LSP servers
            "williamboman/mason-lspconfig.nvim", -- Integration between Mason and nvim-lspconfig
        },
        config = function()
            local lspconfig = require("lspconfig")
            -- Lua
            lspconfig.lua_ls.setup({
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
            })
            -- Rust
            lspconfig.rust_analyzer.setup({})
            -- Python
            lspconfig.pylsp.setup({
                settings = {
                    pylsp = {
                        plugins = {
                            pylint = {
                                maxLineLength = 120,
                            },
                            pycodestyle = {
                                maxLineLength = 120,
                            },
                        },
                    },
                },
            })
            -- Go
            lspconfig.gopls.setup({})
            -- Jsonnet
            lspconfig.jsonnet_ls.setup({})
            -- Bash
            lspconfig.bashls.setup({})
            -- Terraform
            lspconfig.terraformls.setup({})
            -- YAML
            lspconfig.yamlls.setup({})
            -- JSON
            lspconfig.jsonls.setup({})
        end,
    }
}
