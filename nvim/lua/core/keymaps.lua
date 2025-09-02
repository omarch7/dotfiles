---@diagnostic disable-next-line: undefined-global
local keymap = vim.keymap.set

-- LSP mappings
keymap("n", "<leader>F", "<cmd>lua vim.lsp.buf.format({ async = true })<CR>", { noremap = true, silent = true, desc = "Format code" })
keymap("n", "<leader>rn", "<cmd>lua vim.lsp.buf.rename()<CR>", { noremap = true, silent = true, desc = "Rename symbol" })
keymap("n", "<leader>ca", "<cmd>lua vim.lsp.buf.code_action()<CR>", { noremap = true, silent = true, desc = "Code action" })
keymap("n", "<leader>K", "<cmd>lua vim.lsp.buf.hover()<CR>", { noremap = true, silent = true, desc = "Hover documentation" })
keymap("n", "<leader>fb", "<cmd>lua vim.lsp.buf.definition()<CR>", { noremap = true, silent = true, desc = "Go to definition"})

-- Snacks mappings
keymap("n", "<leader><leader>", "<cmd>lua Snacks.picker.smart()<CR>", { desc = "Snacks smart picker" })
keymap("n", "<leader>ff", "<cmd>lua Snacks.picker.files()<CR>", { desc = "Snacks find files" })
keymap("n", "<leader>fg", "<cmd>lua Snacks.picker.grep()<CR>", { desc = "Snacks find inside files" })
keymap("n", "<leader>fr", "<cmd>lua Snacks.picker.lsp_references()<CR>", { noremap = true, silent = true, desc = "Snacks LSP references" })
keymap("n", "<leader>e", "<cmd>lua Snacks.explorer()<CR>", { noremap = true, silent = true, desc = "Snacks explorer" })
keymap("n", "<leader>gg", "<cmd>lua Snacks.lazygit()<CR>", { noremap = true, silent = true, desc = "Snacks lazygit" })
keymap({"n", "v"}, "<leader>gB", "<cmd>lua Snacks.gitbrowse()<CR>", { noremap = true, silent = true, desc = "Snacks git browse" })
keymap("n", "<leader>sd", "<cmd>lua Snacks.picker.diagnostics()<CR>", { noremap = true, silent = true, desc = "Snacks diagnostics" })
keymap("n", "<leader>sD", "<cmd>lua Snacks.picker.diagnostics_buffer()<CR>", { noremap = true, silent = true, desc = "Snacks diagnostics buffer" })
keymap("n", "<c-/>", "<cmd>lua Snacks.terminal()<CR>", { noremap = true, silent = true, desc = "Snacks terminal" })
keymap("n", "<c-_>", "<cmd>lua Snacks.terminal()<CR>", { noremap = true, silent = true, desc = "which_key_ignore" })

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
keymap("n", "<[c>", "<cmd>Gitsigns prev_hunk<CR>", { noremap = true, silent = true, desc = "Gitsigns previous hunk" })
keymap("n", "]c", "<cmd>Gitsigns next_hunk<CR>", { noremap = true, silent = true, desc = "Gitsigns next hunk" })

-- Vim-Test mappings
keymap("n", "<leader>tf", "<cmd>TestFile<CR>", { noremap = true, silent = true, desc = "Run test file" })
keymap("n", "<leader>ts", "<cmd>TestSuite<CR>", { noremap = true, silent = true, desc = "Run test suite" })
keymap("n", "<leader>tn", "<cmd>TestNearest<CR>", { noremap = true, silent = true, desc = "Run nearest test" })
keymap("n", "<leader>tl", "<cmd>TestLast<CR>", { noremap = true, silent = true, desc = "Run last test" })

-- DAP-UI mappings
keymap("n", "<leader>dui", "<cmd>lua require('dapui').toggle()<CR>", { noremap = true, silent = true, desc = "Toggle DAP UI" })
keymap({"n", "v"}, "<leader>due", "<cmd>lua require('dapui').eval()<CR>", { noremap = true, silent = true, desc = "DAP UI eval" })

-- Tmux Navigator mappings
keymap("t", "<C-h>", "<Cmd>TmuxNavigateLeft<CR>", { noremap = true, silent = true, desc = "Tmux navigate left" })
keymap("t", "<C-j>", "<Cmd>TmuxNavigateDown<CR>", { noremap = true, silent = true, desc = "Tmux navigate down" })
keymap("t", "<C-k>", "<Cmd>TmuxNavigateUp<CR>", { noremap = true, silent = true, desc = "Tmux navigate up" })
keymap("t", "<C-l>", "<Cmd>TmuxNavigateRight<CR>", { noremap = true, silent = true, desc = "Tmux navigate right" })
keymap("t", "<C-\\>", "<Cmd>TmuxNavigatePrevious<CR>", { noremap = true, silent = true, desc = "Tmux navigate previous" })
