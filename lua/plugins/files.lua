local function toggle_telescope(harpoon_list)
	local conf = require("telescope.config").values
	local themes = require("telescope.themes")

	local file_paths = {}

	local items = harpoon_list.items or {}
	for _, item in ipairs(items) do
		local path = item.value or item.path
		if path then
			table.insert(file_paths, path)
		end
	end

	local opts = themes.get_ivy({
		prompt_title = "Working List",
	})

	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")

	require("telescope.pickers")
		.new(opts, {
			finder = require("telescope.finders").new_table({
				results = file_paths,
			}),
			previewer = conf.file_previewer(opts),
			sorter = conf.generic_sorter(opts),

			attach_mappings = function(prompt_bufnr, map)
				actions.select_default:replace(function()
					local entry = action_state.get_selected_entry()
					actions.close(prompt_bufnr)

					-- VERY IMPORTANT:
					-- Wait until Telescope fully closes before editing buffer
					vim.schedule(function()
						pcall(vim.cmd, "NvimTreeClose") -- prevent E242 race
						if entry and entry[1] then
							vim.cmd("edit " .. vim.fn.fnameescape(entry[1]))
						end
					end)
				end)

				return true
			end,
		})
		:find()
end

return {

	-- =========================
	-- Telescope
	-- =========================
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
			{
				"nvim-telescope/telescope-fzf-native.nvim",
				build = "make",
			},
		},

		config = function()
			if vim.fn.executable("rg") == 0 then
				vim.notify("Ripgrep not found live_grep won't work!", vim.log.levels.WARN)
			end

			require("telescope").setup({
				extensions = {
					fzf = {},
				},
			})

			local builtin = require("telescope.builtin")

			vim.keymap.set("n", "<leader>fk", function()
				builtin.lsp_document_symbols()
			end, { desc = "Find symbols in current file" })

			vim.keymap.set("n", "<leader>fl", function()
				builtin.lsp_workspace_symbols()
			end, { desc = "Find symbols in current workspace" })

			vim.keymap.set({ "n", "v" }, "<leader>la", function()
				vim.lsp.buf.code_action()
			end, { desc = "LSP Code Actions" })
		end,
	},

	-- =========================
	-- Harpoon 2
	-- =========================
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

	-- =========================
	-- Oil
	-- =========================
	{
		"stevearc/oil.nvim",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		init = function()
			if vim.fn.maparg("-", "n") ~= "" then
				vim.keymap.del("n", "-")
			end

			vim.api.nvim_create_autocmd("VimEnter", {
				callback = function()
					local arg = vim.fn.argv(0)
					if arg ~= "" and vim.fn.isdirectory(arg) == 1 then
						require("oil").open(arg)
					end
				end,
			})
		end,
		keys = {
			{
				"<leader>fo",
				function()
					require("oil").open_float(vim.fn.getcwd())
				end,
				desc = "Oil: Open float (cwd)",
			},
			{
				"-",
				"<CMD>Oil<CR>",
				desc = "Open parent directory",
			},
		},
		opts = {
			default_file_explorer = true,
			columns = { "icon", "size", "mtime" },
			skip_confirm_for_simple_edits = true,
			view_options = { show_hidden = true },
			float = {
				padding = 2,
				max_width = 120,
				max_height = 40,
				border = "rounded",
			},
		},
	},
}
