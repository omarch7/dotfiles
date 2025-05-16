---@diagnostic disable-next-line: undefined-global
local keymap = vim.keymap.set

-- NvimTree Toggle
keymap("n", "<C-n>", ":NvimTreeToggle<CR>", { noremap = true, silent = true, desc = "Toggle NvimTree" })

-- LSP mappings
keymap("n", "<leader>F", "<cmd>lua vim.lsp.buf.format({ async = true })<CR>", { noremap = true, silent = true, desc = "Format code" })
keymap("n", "<leader>rn", "<cmd>lua vim.lsp.buf.rename()<CR>", { noremap = true, silent = true, desc = "Rename symbol" })
keymap("n", "<leader>ca", "<cmd>lua vim.lsp.buf.code_action()<CR>", { noremap = true, silent = true, desc = "Code action" })
keymap("n", "<leader>K", "<cmd>lua vim.lsp.buf.hover()<CR>", { noremap = true, silent = true, desc = "Hover documentation" })

-- Telescope mappings
keymap("n", "<leader>ff", "<cmd>Telescope find_files<CR>", { desc = "Telescope find files" })
keymap("n", "<leader>fg", "<cmd>Telescope live_grep<CR>", { desc = "Telescope find inside files" })
keymap("n", "<leader>fb", "<cmd>Telescope lsp_definitions<CR>", { noremap = true, silent = true, desc = "Telescope LSP definitions" })
keymap("n", "<leader>fr", "<cmd>Telescope lsp_references<CR>", { noremap = true, silent = true, desc = "Telescope LSP references" })

-- DAP mappings
keymap("n", "<leader>dc", "<cmd>Telescope dap commands<CR>", { desc = "Telescope dap commands" })
keymap("n", "<leader>dv", "<cmd>Telescope dap variables<CR>", { desc = "Telescope dap variables" })
keymap("n", "<leader>df", "<cmd>Telescope dap frames<CR>", { desc = "Telescope dap frames" })

keymap("n", "<leader>dd", "<cmd>lua require('dap').continue()<CR>", { noremap = true, silent = true, desc = "DAP continue" })
keymap("n", "<leader>dt", "<cmd>lua require('dap').terminate()<CR>", { noremap = true, silent = true, desc = "DAP terminate" })
keymap("n", "<leader>db", "<cmd>lua require('dap').toggle_breakpoint()<CR>", { noremap = true, silent = true, desc = "DAP toggle breakpoint" })
keymap("n", "<leader>do", "<cmd>lua require('dap').step_over()<CR>", { noremap = true, silent = true, desc = "DAP step over" })
keymap("n", "<leader>du", "<cmd>lua require('dap').step_out()<CR>", { noremap = true, silent = true, desc = "DAP step out" })
keymap("n", "<leader>di", "<cmd>lua require('dap').step_into()<CR>", { noremap = true, silent = true, desc = "DAP step into" })
keymap("n", "<leader>de", "<cmd>lua require('dap').repl.open()<CR>", { noremap = true, silent = true, desc = "DAP open REPL" })

-- DiffView mappings
keymap("n", "<leader>gvm", "<cmd>DiffviewOpen master<CR>", { desc = "DiffView open against master" })
keymap("n", "<leader>gv1", "<cmd>DiffviewOpen HEAD~1<CR>", { desc = "DiffView open against HEAD~1" })
keymap("n", "<leader>gv2", "<cmd>DiffviewOpen HEAD~2<CR>", { desc = "DiffView open against HEAD~2" })
keymap("n", "<leader>gvc", "<cmd>DiffviewClose<CR>", { desc = "DiffView close" })
keymap("n", "<leader>gvh", "<cmd>DiffviewFileHistory<CR>", { desc = "DiffView file history" })

-- Gitsigns mapping
keymap("n", "<leader>gp", "<cmd>Gitsigns preview_hunk<CR>", { noremap = true, silent = true, desc = "Gitsigns preview hunk" })
keymap("n", "<leader>gr", "<cmd>Gitsigns reset_hunk<CR>", { noremap = true, silent = true, desc = "Gitsigns reset hunk" })

-- Vim-Test mappings
keymap("n", "<leader>tf", "<cmd>TestFile<CR>", { noremap = true, silent = true, desc = "Run test file" })
keymap("n", "<leader>ts", "<cmd>TestSuite<CR>", { noremap = true, silent = true, desc = "Run test suite" })
keymap("n", "<leader>tn", "<cmd>TestNearest<CR>", { noremap = true, silent = true, desc = "Run nearest test" })
keymap("n", "<leader>tl", "<cmd>TestLast<CR>", { noremap = true, silent = true, desc = "Run last test" })
