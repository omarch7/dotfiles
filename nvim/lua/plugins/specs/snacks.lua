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
            },
            explorer = {
                enabled = true,
            },
            notifier = {
                enabled = true,
                timeout = 3000,
            },
        }
    }

}
