return {
	{
		"folke/noice.nvim",
		event = "VeryLazy",
		dependencies = {
			"MunifTanjim/nui.nvim",
			-- nvim-notify is optioneel, maar jij gebruikt notify apart:
			-- "rcarriga/nvim-notify",
		},
		opts = {
			cmdline = { enabled = true },
			messages = { enabled = false }, -- voorkomt dat je weer "onderin" spam krijgt van noice
			popupmenu = { enabled = true }, -- cmdline popupmenu (werkt goed met cmp)
			notify = { enabled = false }, -- laat nvim-notify dit doen
			lsp = {
				progress = { enabled = false },
				hover = { enabled = false },
				signature = { enabled = false },
				message = { enabled = false },
			},
			presets = {
				bottom_search = false,
				command_palette = true, -- cmdline + popupmenu netjes uitgelijnd
				long_message_to_split = true,
				inc_rename = false,
				lsp_doc_border = true,
			},
		},
	},

	{
		"rcarriga/nvim-notify",
		event = "VeryLazy",
		opts = {
			stages = "fade_in_slide_out",
			timeout = 2500,
			render = "compact",

			top_down = false,

			max_width = function()
				return math.floor(vim.o.columns * 0.35)
			end,

			max_height = function()
				return math.floor(vim.o.lines * 0.20)
			end,

			background_colour = "Normal",
			minimum_width = 20,

			on_open = function(win)
				vim.api.nvim_win_set_config(win, {
					relative = "editor",
					anchor = "NE",
					row = 2,
					col = vim.o.columns - 2,
				})
			end,
		},
		config = function(_, opts)
			local notify = require("notify")
			notify.setup(opts)
			vim.notify = notify
		end,
	},

	{
		"stevearc/dressing.nvim",
		event = "VeryLazy",
		opts = {
			input = {
				border = "rounded",
				win_options = {
					winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
				},
				relative = "cursor",
				prefer_width = 40,
				insert_only = true,
			},
			select = {
				backend = { "telescope", "builtin" },
				builtin = {
					border = "rounded",
					win_options = {
						winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
					},
				},
				telescope = require("telescope.themes").get_dropdown({
					previewer = false,
					layout_config = { width = 0.5, height = 0.5 },
				}),
			},
		},
	},

	{
		"nvim-lualine/lualine.nvim",
		event = "VeryLazy",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		opts = {
			options = {
				theme = "auto",
				section_separators = { left = "", right = "" },
				component_separators = { left = "│", right = "│" },
				globalstatus = true,
			},
			sections = {
				lualine_a = { "mode" },
				lualine_b = { "branch", "diff" },
				lualine_c = { { "filename", path = 1 } },
				lualine_x = { "encoding", "fileformat", "filetype" },
				lualine_y = { "progress" },
				lualine_z = { "location" },
			},
		},
	},

	{
		"petertriho/nvim-scrollbar",
		event = "BufWinEnter",
		dependencies = { "kevinhwang91/nvim-hlslens" },
		config = function()
			require("scrollbar").setup()
			require("scrollbar.handlers.search").setup()
		end,
	},

	{
		"lukas-reineke/indent-blankline.nvim",
		main = "ibl",
		event = { "BufReadPre", "BufNewFile" },
		opts = {
			indent = {
				char = "│",
				highlight = "IblIndent",
			},
			scope = {
				enabled = true,
				show_start = true,
				show_end = false,
				highlight = "IblScope",
			},
		},
		config = function(_, opts)
			local hooks = require("ibl.hooks")

			hooks.register(hooks.type.HIGHLIGHT_SETUP, function()
				vim.api.nvim_set_hl(0, "IblIndent", {
					fg = "#34302C",
				})

				vim.api.nvim_set_hl(0, "IblScope", {
					fg = "#E16A2D",
					bold = false,
				})
			end)

			require("ibl").setup(opts)
		end,
	},

	{
		"echasnovski/mini.icons",
		version = false,
	},

	{
		"onsails/lspkind.nvim",
	},

	{
		"folke/which-key.nvim",
		event = "VeryLazy",
		opts = {
			plugins = {
				marks = true,
				registers = true,
				spelling = { enabled = true, suggestions = 20 },
			},

			win = {
				border = "rounded",
				padding = { 1, 2, 1, 2 },
			},

			layout = {
				spacing = 6,
				align = "center",
			},

			wo = {
				winblend = 20,
			},
		},
	},
}
