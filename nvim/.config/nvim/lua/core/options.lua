local opt = vim.opt
local g = vim.g
local wo = vim.wo

-- Basic Options
opt.tabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
wo.number = true
wo.relativenumber = true

-- Set leader keys
g.mapleader = " "
g.maplocalleader = "\\"

-- Syntax highlighting
vim.cmd([[syntax on]])

-- Enable Virtual Lines
vim.diagnostic.config({
    virtual_lines = true
})

vim.o.exrc = true
