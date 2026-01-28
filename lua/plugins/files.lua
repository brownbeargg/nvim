local conf = require("telescope.config").values
local themes = require("telescope.themes")

local function toggle_telescope(harpoon_files)
	local file_paths = {}
	for _, item in ipairs(harpoon_files.items) do
		table.insert(file_paths, item.value)
	end
	local opts = themes.get_ivy({
		promt_title = "Working List",
	})

	require("telescope.pickers")
		.new(opts, {
			finder = require("telescope.finders").new_table({
				results = file_paths,
			}),
			previewer = conf.file_previewer(opts),
			sorter = conf.generic_sorter(opts),
		})
		:find()
end

return {
	{
		"nvim-telescope/telescope.nvim",
		dependencies = {
			"nvim-lua/plenary.nvim",
			{
				"nvim-telescope/telescope-ui-select.nvim",
				config = function()
					local telescope = require("telescope")
					telescope.setup({
						extensions = {
							["ui-select"] = require("telescope.themes").get_dropdown(),
						},
					})
					telescope.load_extension("ui-select")
				end,
			},
		},
		config = function()
			if vim.fn.executable("rg") == 0 then
				vim.notify("Ripgrep not found live_grep won't work!", vim.log.levels.WARN)
			end

			local builtin = require("telescope.builtin")

			vim.keymap.set("n", "<leader>fp", builtin.help_tags, { desc = "Find help" })
			vim.keymap.set("n", "<leader>fa", builtin.buffers, { desc = "Find buffers" })
			vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Find files" })
			vim.keymap.set("n", "<leader>fd", builtin.live_grep, { desc = "Find grep" })
			vim.keymap.set("n", "<leader>fs", builtin.commands, { desc = "Find commands" })
			vim.keymap.set("n", "<leader>fg", builtin.git_files, { desc = "Find git files" })

			vim.keymap.set("n", "<leader>fi", function()
				require("telescope.builtin").current_buffer_fuzzy_find()
			end, { desc = "find in current buffer" })

			vim.keymap.set({ "n", "v" }, "<leader>lca", function()
				vim.lsp.buf.code_action()
			end, { desc = "LSP Code Actions" })
		end,
	},

	{
		"ThePrimeagen/harpoon",
		branch = "harpoon2",
		dependencies = {
			"nvim-lua/plenary.nvim",
		},
		config = function()
			local harpoon = require("harpoon")
			vim.keymap.set("n", "<leader>fj", function()
				harpoon:list():add()
			end)
			vim.keymap.set("n", "<leader>hc", function()
				harpoon.ui:toggle_quick_menu(harpoon:list())
			end)
			vim.keymap.set("n", "<leader>hl", function()
				toggle_telescope(harpoon:list())
			end, { desc = "Open harpoon window" })

			vim.keymap.set("n", "g(", function()
				harpoon:list():prev()
			end)
			vim.keymap.set("n", "g)", function()
				harpoon:list():next()
			end)

			for i = 1, 9 do
				vim.keymap.set("n", "g" .. i, function()
					harpoon:list():select(i)
				end, { desc = "Harpoon select " .. i })
			end
		end,
	},

	{
		"stevearc/oil.nvim",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		keys = {
			init = function()
				vim.keymap.del("n", "-")
			end,

			{
				"<leader>fo",
				function()
					require("oil").open_float(vim.fn.getcwd())
				end,
				desc = "Oil: Open float (cwd)",
			},
		},
		opts = {
			default_file_explorer = false,
			columns = { "icon", "size", "mtime" },
			skip_confirm_for_simple_edits = true,
			view_options = { show_hidden = true },
			float = { padding = 2, max_width = 120, max_height = 40, border = "rounded" },
		},
	},

	{
		"nvim-tree/nvim-tree.lua",
		dependencies = {
			"nvim-tree/nvim-web-devicons",
		},
		cmd = "NvimTreeToggle",
		keys = {
			{
				"<C-e>",
				function()
					vim.cmd("NvimTreeToggle")
				end,
				desc = "Toggle tree",
			},
		},
		config = function()
			require("nvim-tree").setup({
				view = {
					side = "right",
				},
			})
		end,
	},
}
