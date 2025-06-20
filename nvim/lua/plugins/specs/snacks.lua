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
                        auto_close = true,
                        win = {
                            list = {
                                keys = {
                                    ["o"] = "confirm",
                                },
                            },
                        },
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
                    position = "float",
                },
            },
        }
    }

}
