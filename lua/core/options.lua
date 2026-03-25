-- line numbers
vim.opt.number = true
vim.opt.relativenumber = true

-- indenting
vim.opt.tabstop = 4
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

vim.opt.smartindent = true

vim.opt.wrap = false

-- recovery
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undofile = true

local undodir = vim.fn.stdpath("data") .. "/undodir"
if not vim.loop.fs_stat(undodir) then
	vim.fn.mkdir(undodir, "p")
end
vim.opt.undodir = undodir

-- search
vim.opt.incsearch = true

-- gui
vim.opt.termguicolors = true

-- scrolling
vim.opt.scrolloff = 15
vim.opt.signcolumn = "yes"
vim.opt.isfname:append("@-@")

-- update
vim.opt.updatetime = 50

-- lsp
vim.opt.signcolumn = "yes"

-- disable netrw
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
