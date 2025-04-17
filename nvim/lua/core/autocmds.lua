vim.api.nvim_create_autocmd({ "VimEnter" }, {
    callback = function()
        if vim.fn.argc() == 0 then
            require("nvim-tree.api").tree.open()
        end
    end,
})

vim.api.nvim_create_autocmd("BufEnter", {
    nested = true,
    callback = function()
        local tree_wins = {}
        local normal_wins = {}

        for _, win in ipairs(vim.api.nvim_list_wins()) do
            local bufname = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win))
            if bufname:match("NvimTree_") then
                table.insert(tree_wins, win)
            else
                table.insert(normal_wins, win)
            end
        end

        if #normal_wins == 0 then
            vim.cmd("quit")
        end
    end,
})
