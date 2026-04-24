return {
    {
        "zbirenbaum/copilot.lua",
        config = function()
            require("copilot").setup({
                suggestion = {
                    enabled = true,
                    auto_trigger = true,
                    debounce = 75,
                    keymap = {
                        accept = "<M-l>",      -- Alt+L to accept
                        accept_word = "<M-w>", -- Alt+W to accept word
                        accept_line = "<M-j>", -- Alt+J to accept line
                        next = "<M-]>",        -- Alt+] for next suggestion
                        prev = "<M-[>",        -- Alt+[ for previous suggestion
                        dismiss = "<C-]>",     -- Ctrl+] to dismiss
                    },
                },
            })
        end,
    },
}
