return {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    cmd = "ConformInfo",
    opts = {
        formatters_by_ft = {
            graphql = { "prettier" },
        },
        default_format_opts = {
            lsp_format = "fallback",
        },
    },
}
