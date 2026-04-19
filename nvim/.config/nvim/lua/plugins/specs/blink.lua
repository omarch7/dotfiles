return {
    {
        'saghen/blink.cmp',
        dependencies = 'rafamadriz/friendly-snippets',
        version = '1.7.0',
        opts = {
            keymap = { preset = 'default' },
            appearance = {
                use_nvim_cmp_as_default = true,
                nerd_font_variant = 'mono',
            },
            sources = {
                default = { 'lsp', 'path', 'snippets', 'buffer' },
            },
            cmdline = {
                keymap = { preset = 'inherit' },
                completion = { menu = { auto_show = true } },
            },
            completion = {
                menu = {
                    auto_show_delay_ms = function(_, _) return vim.bo.filetype == 'markdown' and 10000 or 0 end,
                },
            },
        },
        opts_extend = { 'sources.default' }
    },
}
