local keymap = vim.keymap.set

-- NvimTree Toggle
keymap("n", "<C-n>", ":NvimTreeToggle<CR>", { noremap = true, silent = true })

-- LSP mappings
keymap("n", "<leader>F", function()
    vim.lsp.buf.format({ async = true })
end, { noremap = true, silent = true })
keymap("n", "<leader>rn", function()
    vim.lsp.buf.rename()
end, { noremap = true, silent = true })
keymap("n", "<leader>ca", function()
    vim.lsp.buf.code_action()
end, { noremap = true, silent = true })
keymap("n", "<leader>K", function()
    vim.lsp.buf.hover()
end, { noremap = true, silent = true })

-- Telescope mappings
keymap("n", "<leader>ff", "<cmd>Telescope find_files<CR>", { desc = "Telescope find files" })
keymap("n", "<leader>fg", "<cmd>Telescope live_grep<CR>", { desc = "Telescope find inside files" })
keymap("n", "<leader>fb", "<cmd>Telescope lsp_definitions<CR>", { noremap = true, silent = true })
keymap("n", "<leader>fr", "<cmd>Telescope lsp_references<CR>", { noremap = true, silent = true })

-- DAP mappings
keymap("n", "<leader>dc", "<cmd>Telescope dap commands<CR>", { desc = "Telescope dap commands" })
keymap("n", "<leader>dv", "<cmd>Telescope dap variables<CR>", { desc = "Telescope dap variables" })
keymap("n", "<leader>df", "<cmd>Telescope dap frames<CR>", { desc = "Telescope dap frames" })

keymap("n", "<leader>dd", "<cmd>lua require('dap').continue()<CR>", { noremap = true, silent = true })
keymap("n", "<leader>dt", "<cmd>lua require('dap').terminate()<CR>", { noremap = true, silent = true })
keymap("n", "<leader>db", "<cmd>lua require('dap').toggle_breakpoint()<CR>", { noremap = true, silent = true })
keymap("n", "<leader>do", "<cmd>lua require('dap').step_over()<CR>", { noremap = true, silent = true })
keymap("n", "<leader>du", "<cmd>lua require('dap').step_out()<CR>", { noremap = true, silent = true })
keymap("n", "<leader>di", "<cmd>lua require('dap').step_into()<CR>", { noremap = true, silent = true })
keymap("n", "<leader>de", "<cmd>lua require('dap').repl.open()<CR>", { noremap = true, silent = true })

-- DiffView mappings
keymap("n", "<leader>dvm", "<cmd>DiffviewOpen master<CR>", { desc = "DiffView open against master" })
keymap("n", "<leader>dv1", "<cmd>DiffviewOpen HEAD~1<CR>", { desc = "DiffView open against HEAD~1" })
keymap("n", "<leader>dvc", "<cmd>DiffviewClose<CR>", { desc = "DiffView close" })
keymap("n", "<leader>dvh", "<cmd>DiffviewFileHistory<CR>", { desc = "DiffView file history" })

-- Gitsigns mapping
keymap("n", "<leader>gp", "<cmd>Gitsigns preview_hunk<CR>", { desc = "Gitsigns preview hunk" })

-- Vim-Test mappings
keymap("n", "<leader>tf", "<cmd>TestFile<CR>", { desc = "Test file" })
keymap("n", "<leader>ts", "<cmd>TestSuite<CR>", { desc = "Test suite" })
keymap("n", "<leader>tn", "<cmd>TestNearest<CR>", { desc = "Test nearest" })
keymap("n", "<leader>tl", "<cmd>TestLast<CR>", { desc = "Test last" })
