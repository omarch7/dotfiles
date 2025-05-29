return {
    {
        "mfussenegger/nvim-dap",
        config = function()
            require("dap").set_log_level("TRACE")
            require("dap").defaults.fallback.terminal_win_cmd = "50vsplit new"

            local catppuccin = require("catppuccin.palettes").get_palette()

            -- Set up highlight groups
            vim.api.nvim_set_hl(0, 'DapBreakpoint', { fg = catppuccin.red })
            vim.api.nvim_set_hl(0, 'DapLogPoint', { fg = catppuccin.blue })
            vim.api.nvim_set_hl(0, 'DapStopped', { fg = catppuccin.green })

            -- Define signs
            vim.fn.sign_define('DapBreakpoint', { text = '●', texthl = 'DapBreakpoint' })
            vim.fn.sign_define('DapBreakpointCondition', { text = '◆', texthl = 'DapBreakpoint' })
            vim.fn.sign_define('DapLogPoint', { text = '◉', texthl = 'DapLogPoint' })
            vim.fn.sign_define('DapStopped', { text = '▶', texthl = 'DapStopped' })
        end,
    },
    {
        "mfussenegger/nvim-dap-python",
        dependencies = { "mfussenegger/nvim-dap" },
        config = function()
            require("dap-python").setup("python3")
        end,
    },
    {
        "leoluz/nvim-dap-go",
        dependencies = { "mfussenegger/nvim-dap" },
        config = function()
            require("dap-go").setup()
        end,
    },
    {
        "theHamsta/nvim-dap-virtual-text",
        dependencies = { "mfussenegger/nvim-dap" },
        config = function()
            require("nvim-dap-virtual-text").setup()
        end,
    },
    {
        "nvim-telescope/telescope-dap.nvim",
        dependencies = {
            "mfussenegger/nvim-dap",
            "nvim-telescope/telescope.nvim",
        },
        config = function()
            require('telescope').load_extension('dap')
        end,
    },
}
