return {
	{
		"nvim-treesitter/nvim-treesitter",
		build = ":TSUpdate",
		event = { "BufReadPost", "BufNewFile" },
		dependencies = {
			{ "nvim-treesitter/nvim-treesitter-textobjects", lazy = false },
			"HiPhish/rainbow-delimiters.nvim",
			"nvim-treesitter/playground",
		},
		config = function()
			require("nvim-treesitter.configs").setup({
				ensure_installed = { "cpp", "c", "glsl", "lua", "vim", "bash" },
				highlight = { enable = true },
				indent = { enable = true },
				textobjects = {
					select = {
						enable = true,
						lookahead = true,
						keymaps = {
							["af"] = "@function.outer",
							["if"] = "@function.inner",
							["ac"] = "@class.outer",
							["ic"] = "@class.inner",
						},
						include_surrounding_whitespace = true,
					},
					move = {
						enable = true,
						set_jumps = true,
						goto_next_start = { ["]f"] = "@function.outer", ["]c"] = "@class.outer" },
						goto_next_end = { ["]F"] = "@function.outer", ["]C"] = "@class.outer" },
						goto_previous_start = { ["[f"] = "@function.outer", ["[c"] = "@class.outer" },
						goto_previous_end = { ["[F"] = "@function.outer", ["[C"] = "@class.outer" },
					},
				},
			})

			local rainbow_delimiters = require("rainbow-delimiters")
			vim.g.rainbow_delimiters = {
				strategy = { [""] = rainbow_delimiters.strategy["global"] },
				query = { [""] = "rainbow-delimiters" },
				highlight = {
					"RainbowDelimiterYellow",
					"RainbowDelimiterOrange",
					"RainbowDelimiterCyan",
					"RainbowDelimiterBlue",
					"RainbowDelimiterViolet",
				},
			}
		end,
	},

	{
		"nvim-treesitter/nvim-treesitter-textobjects",
	},

	{
		"folke/todo-comments.nvim",
		event = { "BufReadPre", "BufNewFile" },
		dependencies = { "nvim-lua/plenary.nvim" },
		opts = {
			signs = true,
			highlight = {
				before = "",
				keyword = "wide",
				after = "fg",
			},
			keywords = {
				TODO = { icon = " ", color = "info" },
				FIX = { icon = " ", color = "error" },
				HACK = { icon = " ", color = "warning" },
				NOTE = { icon = " ", color = "hint" },
			},
			search = {
				command = "rg",
				args = {
					"--color=never",
					"--no-heading",
					"--with-filename",
					"--line-number",
					"--column",
				},
			},
		},
	},
	{
		"numToStr/Comment.nvim",
		event = "VeryLazy",
		opts = {
			padding = true,
			sticky = true,
			ignore = "^$",
			mappings = {
				basic = true, -- gcc, gc
				extra = true, -- gco, gcO, gcA
			},
		},
	},

	{
		"kylechui/nvim-surround",
		event = "VeryLazy",

		config = function()
			vim.g.nvim_surround_no_mappings = true

			-- INSERT MODE
			vim.keymap.set("i", "<C-s>i", "<Plug>(nvim-surround-insert)", { desc = "Surround insert" })
			vim.keymap.set("i", "<C-s>l", "<Plug>(nvim-surround-insert-line)", { desc = "Surround insert line" })

			-- NORMAL MODE
			vim.keymap.set("n", "<C-s>n", "<Plug>(nvim-surround-normal)", { desc = "Surround normal" })
			vim.keymap.set("n", "<C-s>x", "<Plug>(nvim-surround-normal-cur)", { desc = "Surround current" })

			-- VISUAL MODE
			vim.keymap.set("x", "<C-s>a", "<Plug>(nvim-surround-visual)", { desc = "Surround visual" })
			vim.keymap.set("x", "<C-s>n", "<Plug>(nvim-surround-visual-line)", { desc = "Surround visual line" })

			-- DELETE / CHANGE
			vim.keymap.set("n", "<C-s>d", "<Plug>(nvim-surround-delete)", { desc = "Delete surround" })
			vim.keymap.set("n", "<C-s>c", "<Plug>(nvim-surround-change)", { desc = "Change surround" })
		end,
	},

	{
		"windwp/nvim-autopairs",
		event = "InsertEnter",
		opts = {
			check_ts = true,
			fast_wrap = {
				map = "<M-e>",
				chars = { "{", "[", "(", '"', "'" },
				pattern = "[%'%\"%)%>%]%)%}%,]",
				offset = 0,
				end_key = "$",
				keys = "qwertyuiopzxcvbnmasdfghjkl",
				check_comma = true,
				highlight = "Search",
				highlight_grey = "Comment",
			},
		},
	},

	{
		"ThePrimeagen/refactoring.nvim",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-treesitter/nvim-treesitter",
		},
		keys = {
			{
				"<leader>rs",
				function()
					require("refactoring").select_refactor()
				end,
				mode = { "n", "v" },
				desc = "Refactor: Select",
			},
			{
				"<leader>ref",
				function()
					require("refactoring").refactor("Extract Function")
				end,
				mode = "v",
				desc = "Refactor: Extract Function",
			},
			{
				"<leader>rff",
				function()
					require("refactoring").refactor("Extract Function To File")
				end,
				mode = "v",
				desc = "Refactor: Extract Function To File",
			},
			{
				"<leader>rev",
				function()
					require("refactoring").refactor("Extract Variable")
				end,
				mode = "v",
				desc = "Refactor: Extract Variable",
			},
			{
				"<leader>riv",
				function()
					require("refactoring").refactor("Inline Variable")
				end,
				mode = { "n", "v" },
				desc = "Refactor: Inline Variable",
			},
			{
				"<leader>reb",
				function()
					require("refactoring").refactor("Extract Block")
				end,
				mode = "n",
				desc = "Refactor: Extract Block",
			},
			{
				"<leader>rbf",
				function()
					require("refactoring").refactor("Extract Block To File")
				end,
				mode = "n",
				desc = "Refactor: Extract Block To File",
			},
		},
		config = function()
			require("refactoring").setup({
				prompt_func_return_type = {
					go = true,
					java = true,
					cpp = true,
					c = true,
					h = true,
					hpp = true,
					cxx = true,
				},
				prompt_func_param_type = {
					go = true,
					java = true,
					cpp = true,
					c = true,
					h = true,
					hpp = true,
					cxx = true,
				},
			})
		end,
	},
	{
		"monaqa/dial.nvim",
		keys = {
			{
				"<leader>ji",
				function()
					require("dial.map").manipulate("increment", "normal")
				end,
				mode = "n",
				desc = "Dial: Increment",
			},
			{
				"<leader>jd",
				function()
					require("dial.map").manipulate("decrement", "normal")
				end,
				mode = "n",
				desc = "Dial: Decrement",
			},
			{
				"<leader>jgi",
				function()
					require("dial.map").manipulate("increment", "gnormal")
				end,
				mode = "n",
				desc = "Dial: Increment (g)",
			},
			{
				"<leader>jgd",
				function()
					require("dial.map").manipulate("decrement", "gnormal")
				end,
				mode = "n",
				desc = "Dial: Decrement (g)",
			},

			{
				"<leader>jvi",
				function()
					require("dial.map").manipulate("increment", "visual")
				end,
				mode = "v",
				desc = "Dial: Increment (visual)",
			},
			{
				"<leader>jvd",
				function()
					require("dial.map").manipulate("decrement", "visual")
				end,
				mode = "v",
				desc = "Dial: Decrement (visual)",
			},
			{
				"<leader>jgvi",
				function()
					require("dial.map").manipulate("increment", "gvisual")
				end,
				mode = "v",
				desc = "Dial: Increment (visual g)",
			},
			{
				"<leader>jgvd",
				function()
					require("dial.map").manipulate("decrement", "gvisual")
				end,
				mode = "v",
				desc = "Dial: Decrement (visual g)",
			},
		},
		config = function()
			local augend = require("dial.augend")
			require("dial.config").augends:register_group({
				default = {
					augend.integer.alias.decimal,
					augend.integer.alias.hex,
					augend.date.alias["%Y-%m-%d"],
					augend.date.alias["%d/%m/%Y"],
					augend.constant.alias.bool,
					augend.constant.new({ elements = { "and", "or" }, word = true, cyclic = true }),
					augend.constant.new({ elements = { "&&", "||" }, word = false, cyclic = true }),
					augend.constant.new({ elements = { "on", "off" }, word = true, cyclic = true }),
					augend.constant.new({ elements = { "enable", "disable" }, word = true, cyclic = true }),
				},
			})
		end,
	},

	{
		"folke/flash.nvim",
		event = "VeryLazy",
		opts = {
			jump = {
				autojump = false,
			},
			label = {
				uppercase = false,
				current = true,
				after = true,
				before = false,
				exclude = "hjkl",
			},
			modes = {
				char = {
					enabled = true,
					jump_labels = false,
				},
			},
		},
		keys = {
			{
				"s",
				function()
					require("flash").jump()
				end,
				mode = { "n", "x", "o" },
				desc = "Flash Jump",
			},
			{
				"S",
				function()
					require("flash").treesitter()
				end,
				mode = { "n", "x", "o" },
				desc = "Flash Treesitter",
			},
		},
	},

	{
		"gbprod/yanky.nvim",
		dependencies = {
			"nvim-telescope/telescope.nvim",
		},
		config = function()
			require("yanky").setup({
				highlight = {
					timer = 200,
				},
				preserve_cursor_position = {
					enabled = true,
				},
			})

			require("telescope").load_extension("yank_history")

			vim.keymap.set({ "n", "x" }, "y", "<Plug>(YankyYank)")
			vim.keymap.set({ "n", "x" }, "p", "<Plug>(YankyPutAfter)")
			vim.keymap.set({ "n", "x" }, "P", "<Plug>(YankyPutBefore)")
			vim.keymap.set("n", "gp", "<Plug>(YankyGPutAfter)")
			vim.keymap.set("n", "gP", "<Plug>(YankyGPutBefore)")

			vim.keymap.set("n", "<c-y>f", "<Plug>(YankyCycleForward)")
			vim.keymap.set("n", "<c-y>b", "<Plug>(YankyCycleBackward)")
			vim.keymap.set("n", "<c-y>h", "<cmd>Telescope yank_history<cr>")
		end,
	},

	{
		"mbbill/undotree",

		keys = {
			{ "<leader>u", "<cmd>UndotreeToggle<CR>", desc = "Undotree: Toggle" },
		},

		config = function()
			vim.opt.undofile = true
			vim.g.undotree_SetFocusWhenToggle = 1
		end,
	},
	{
		"chentoast/marks.nvim",
		event = "VeryLazy",
		config = function()
			require("marks").setup({
				sign_priority = 10,
				builtin_marks = {},
				cyclic = true,
				default_mappings = false,

				force_write_shada = false,

				excluded_buftypes = { "nofile", "prompt", "terminal" },
				excluded_filetypes = { "TelescopePrompt", "lazy", "mason", "help" },
			})

			local map = vim.keymap.set

			map("n", "<leader>mt", "<cmd>MarksToggleSigns<CR>", { desc = "Marks: toggle signs" })

			map("n", "<leader>ml", "<cmd>MarksListBuf<CR>", { desc = "Marks: list buffer" })
			map("n", "<leader>ma", "<cmd>MarksListAll<CR>", { desc = "Marks: list all" })
			map("n", "<leader>mg", "<cmd>MarksListGlobal<CR>", { desc = "Marks: list global" })

			map("n", "<leader>mv", "<Plug>(Marks-preview)", { desc = "Marks: preview (float)" })
			map("n", "<leader>mc", "<Plug>(Marks-deletebuf)", { desc = "Marks: clear buffer marks" })

			map("n", "]m", "<Plug>(Marks-next)", { desc = "Marks: next" })
			map("n", "[m", "<Plug>(Marks-prev)", { desc = "Marks: prev" })
		end,
	},

	{
		"Civitasv/cmake-tools.nvim",
		ft = { "c", "cpp", "h", "hpp", "cmake" },
		cmd = {
			"CMakeGenerate",
			"CMakeBuild",
			"CMakeBuildCurrentFile",
			"CMakeRun",
			"CMakeRunCurrentFile",
			"CMakeDebug",
			"CMakeDebugCurrentFile",
			"CMakeRunTest",
			"CMakeSelectBuildTarget",
			"CMakeSelectLaunchTarget",
			"CMakeSelectConfigurePreset",
			"CMakeSelectBuildPreset",
			"CMakeSelectCwd",
			"CMakeSelectBuildDir",
			"CMakeOpenCache",
			"CMakeClean",
			"CMakeInstall",
			"CMakeQuickStart",
			"CMakeLaunchArgs",
		},

		keys = {
			{ "<leader>cg", "<cmd>CMakeGenerate<CR>", desc = "CMake Generate" },
			{ "<leader>cG", "<cmd>CMakeGenerate!<CR>", desc = "CMake Clean Generate" },

			{ "<leader>cb", "<cmd>CMakeBuild<CR>", desc = "CMake Build" },
			{ "<leader>cB", "<cmd>CMakeBuild!<CR>", desc = "CMake Clean Build" },
			{ "<leader>cf", "<cmd>CMakeBuildCurrentFile<CR>", desc = "CMake Build Current File" },

			{ "<leader>cr", "<cmd>CMakeRun<CR>", desc = "CMake Run" },
			{ "<leader>cF", "<cmd>CMakeRunCurrentFile<CR>", desc = "CMake Run Current File" },
			{ "<leader>cd", "<cmd>CMakeDebug<CR>", desc = "CMake Debug" },
			{ "<leader>cD", "<cmd>CMakeDebugCurrentFile<CR>", desc = "CMake Debug Current File" },

			{ "<leader>ct", "<cmd>CMakeRunTest<CR>", desc = "CMake Run Tests" },
			{ "<leader>ca", "<cmd>CMakeLaunchArgs<CR>", desc = "CMake Launch Args" },

			{ "<leader>cT", "<cmd>CMakeSelectBuildTarget<CR>", desc = "CMake Build Target" },
			{ "<leader>cL", "<cmd>CMakeSelectLaunchTarget<CR>", desc = "CMake Launch Target" },
			{ "<leader>cp", "<cmd>CMakeSelectConfigurePreset<CR>", desc = "CMake Configure Preset" },
			{ "<leader>cP", "<cmd>CMakeSelectBuildPreset<CR>", desc = "CMake Build Preset" },

			{ "<leader>cw", "<cmd>CMakeSelectCwd<CR>", desc = "CMake Workspace Root" },
			{ "<leader>cm", "<cmd>CMakeSelectBuildDir<CR>", desc = "CMake Build Directory" },
			{ "<leader>cc", "<cmd>CMakeOpenCache<CR>", desc = "CMake Open Cache" },
			{ "<leader>ck", "<cmd>CMakeClean<CR>", desc = "CMake Clean" },
			{ "<leader>ci", "<cmd>CMakeInstall<CR>", desc = "CMake Install" },
			{ "<leader>cq", "<cmd>CMakeQuickStart<CR>", desc = "CMake Quick Start" },
		},

		opts = function()
			return {
				cmake_command = "cmake",
				ctest_command = "ctest",
				ctest_show_labels = true,

				cmake_use_preset = true,
				cmake_regenerate_on_save = true,

				cmake_generate_options = {
					"-DCMAKE_EXPORT_COMPILE_COMMANDS=1",
				},

				cmake_build_options = {},

				cmake_compile_commands_options = {
					-- zet compile_commands.json in je project root
					-- zodat clangd hem altijd vindt
					action = "copy",
					target = vim.loop.cwd(),
				},

				cmake_dap_configuration = {
					name = "cpp",
					type = "codelldb",
					request = "launch",
					stopOnEntry = false,
					runInTerminal = true,
					console = "integratedTerminal",
				},

				cmake_executor = {
					name = "terminal",
					opts = {
						name = "CMake Build",
						prefix_name = "[CMakeTools] ",
						split_direction = "horizontal",
						split_size = 12,
						single_terminal_per_instance = true,
						single_terminal_per_tab = true,
						keep_terminal_static_location = true,
						auto_resize = true,
						start_insert = false,
						focus = false,
						do_not_add_newline = false,
						use_shell_alias = false,
					},
				},

				cmake_runner = {
					name = "terminal",
					opts = {
						name = "CMake Run",
						prefix_name = "[CMakeTools] ",
						split_direction = "horizontal",
						split_size = 12,
						single_terminal_per_instance = true,
						single_terminal_per_tab = true,
						keep_terminal_static_location = true,
						auto_resize = true,
						start_insert = false,
						focus = false,
						do_not_add_newline = false,
						use_shell_alias = false,
					},
				},

				cmake_notifications = {
					runner = { enabled = true },
					executor = { enabled = true },
					spinner = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
					refresh_rate_ms = 100,
				},

				cmake_virtual_text_support = true,
				cmake_use_scratch_buffer = false,
			}
		end,
	},
}
