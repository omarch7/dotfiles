return {
  {
    "mrjones2014/smart-splits.nvim",
    -- Not lazy: the herdr mux backend must be resolvable and the multiplexer
    -- integration active at startup (matches smart-splits' guidance for mux use).
    lazy = false,
    opts = {
      at_edge = "stop",                  -- hand off to herdr at the edge; never wrap inside nvim
      multiplexer_integration = "herdr", -- loads lua/smart-splits/mux/herdr.lua from our runtimepath
    },
    config = function(_, opts)
      require("smart-splits").setup(opts)
      local ss = require("smart-splits")
      local map = vim.keymap.set
      -- move (normal mode) — mirrors the old vim-tmux-navigator C-h/j/k/l
      map("n", "<C-h>", ss.move_cursor_left,  { silent = true, desc = "Move to left split / herdr pane" })
      map("n", "<C-j>", ss.move_cursor_down,  { silent = true, desc = "Move to below split / herdr pane" })
      map("n", "<C-k>", ss.move_cursor_up,    { silent = true, desc = "Move to above split / herdr pane" })
      map("n", "<C-l>", ss.move_cursor_right, { silent = true, desc = "Move to right split / herdr pane" })
      -- resize (normal mode)
      map("n", "<C-A-h>", ss.resize_left,  { silent = true, desc = "Resize split left" })
      map("n", "<C-A-j>", ss.resize_down,  { silent = true, desc = "Resize split down" })
      map("n", "<C-A-k>", ss.resize_up,    { silent = true, desc = "Resize split up" })
      map("n", "<C-A-l>", ss.resize_right, { silent = true, desc = "Resize split right" })
    end,
  },
}
