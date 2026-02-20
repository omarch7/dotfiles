vim.api.nvim_create_autocmd("BufEnter", {
    nested = true,
    callback = function()
        if vim.bo.filetype == "snacks_dashboard" then
            return
        end

        local dominated_by_special = true
        for _, win in ipairs(vim.api.nvim_list_wins()) do
            local buf = vim.api.nvim_win_get_buf(win)
            if (vim.bo[buf].buflisted and vim.bo[buf].buftype == "") or vim.bo[buf].filetype == "snacks_dashboard" then
                dominated_by_special = false
                break
            end
        end

        if dominated_by_special then
            local current_win = vim.api.nvim_get_current_win()
            for _, win in ipairs(vim.api.nvim_list_wins()) do
                if win ~= current_win then
                    pcall(vim.api.nvim_win_close, win, true)
                end
            end

            local ok = pcall(function()
                Snacks.dashboard.open()
            end)
            if not ok then
                vim.cmd("quit")
            end
        end
    end,
})

vim.api.nvim_create_autocmd("User", {
    pattern = "BlinkCmpMenuOpen",
    callback = function()
        vim.b.copilot_suggestion_hidden = true
    end,
})

vim.api.nvim_create_autocmd("User", {
    pattern = "BlinkCmpMenuClose",
    callback = function()
        vim.b.copilot_suggestion_hidden = false
    end,
})
