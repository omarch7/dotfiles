return {
    {
        "folke/snacks.nvim",
        opts = {
            dashboard = {
                sections = {
                    { section = "header" },
                    { section = "keys", gap = 1 },
                    { icon = " ", title = "Recent Files", section = "recent_files", indent = 2, padding = { 2, 2 } },
                    { icon = " ", title = "Projects", section = "projects", indent = 2, padding = 2 },
                    { section = "startup" },
                },
            },
            picker = {
                enabled = true,
                sources = {
                    explorer = {
                        auto_close = false,
                        hidden = true,  -- Show hidden files by default
                        win = {
                            list = {
                                keys = {
                                    ["o"] = "confirm",
                                },
                            },
                        },
                    },
                    grep = {
                        hidden = true,
                        no_ignore = false,
                    },
                },
            },
            explorer = {
                enabled = true,
            },
            notifier = {
                enabled = true,
                timeout = 3000,
            },
            terminal = {
                win = {
                    position = "bottom",
                    height = 0.3,
                },
            },
        }
    }
}
