local opts = { noremap = true, silent = true }

--switching modes
vim.api.nvim_set_keymap("i", "<C-c>", "<Esc>", { noremap = false })
vim.api.nvim_set_keymap("v", "<C-c>", "<Esc>", { noremap = false })

-- move lines
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

vim.keymap.set("n", "J", "mzJ`z")

-- page jumping
vim.keymap.set("n", "C-d", "<C-d>zz")
vim.keymap.set("n", "C-u", "<C-u>zz")

vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")

-- copy, paste and delete
vim.keymap.set("x", "<leader>p", '"_dP')

vim.keymap.set("n", "<leader>y", '"+y')
vim.keymap.set("n", "<leader>Y", '"+Y')
vim.keymap.set("v", "<leader>y", '"+y')

vim.keymap.set("n", "<leaderd", '"_d')
vim.keymap.set("v", "<leaderd", '"_d')

-- quickfix list
vim.keymap.set("n", "<C-c>", "<cmd>cnext<CR>zz")
vim.keymap.set("n", "<C-x>", "<cmd>cprev<CR>zz")

-- replacing
vim.keymap.set("n", "<leader>s", ":%s/\\<<C-r><C-w>\\>/<C-r><C-w>/gI<left><left><left>")

-- moving between windows
vim.keymap.set("n", "<C-h>", "<C-w><C-h>")
vim.keymap.set("n", "<C-j>", "<C-w><C-j>")
vim.keymap.set("n", "<C-k>", "<C-w><C-k>")
vim.keymap.set("n", "<C-l>", "<C-w><C-l>")

-- Resize height and width of a window with the arrow keys
vim.keymap.set("n", "<Up>", ":resize +2<CR>", opts)
vim.keymap.set("n", "<Down>", ":resize -2<CR>", opts)
vim.keymap.set("n", "<Left>", ":vertical resize +2<CR>", opts)
vim.keymap.set("n", "<Right>", ":vertical resize -2<CR>", opts)

vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")
