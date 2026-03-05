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
			vim.keymap.set("n", "<C-s>nn", "<Plug>(nvim-surround-normal)", { desc = "Surround normal" })
			vim.keymap.set("n", "<C-s>nc", "<Plug>(nvim-surround-normal-cur)", { desc = "Surround current" })
			vim.keymap.set("n", "<C-s>nl", "<Plug>(nvim-surround-normal-line)", { desc = "Surround line" })
			vim.keymap.set("n", "<C-s>ncl", "<Plug>(nvim-surround-normal-cur-line)", { desc = "Surround current line" })

			-- VISUAL MODE
			vim.keymap.set("x", "<C-s>vv", "<Plug>(nvim-surround-visual)", { desc = "Surround visual" })
			vim.keymap.set("x", "<C-s>vl", "<Plug>(nvim-surround-visual-line)", { desc = "Surround visual line" })

			-- DELETE / CHANGE
			vim.keymap.set("n", "<C-s>d", "<Plug>(nvim-surround-delete)", { desc = "Delete surround" })
			vim.keymap.set("n", "<C-s>c", "<Plug>(nvim-surround-change)", { desc = "Change surround" })
			-- INSERT MODE
			vim.keymap.set("i", "<C-s>i", "<Plug>(nvim-surround-insert)", { desc = "Surround insert" })
			vim.keymap.set("i", "<C-s>l", "<Plug>(nvim-surround-insert-line)", { desc = "Surround insert line" })

			-- NORMAL MODE
			vim.keymap.set("n", "<C-s>nn", "<Plug>(nvim-surround-normal)", { desc = "Surround normal" })
			vim.keymap.set("n", "<C-s>nc", "<Plug>(nvim-surround-normal-cur)", { desc = "Surround current" })
			vim.keymap.set("n", "<C-s>nl", "<Plug>(nvim-surround-normal-line)", { desc = "Surround line" })
			vim.keymap.set("n", "<C-s>ncl", "<Plug>(nvim-surround-normal-cur-line)", { desc = "Surround current line" })

			-- VISUAL MODE
			vim.keymap.set("x", "<C-s>vv", "<Plug>(nvim-surround-visual)", { desc = "Surround visual" })
			vim.keymap.set("x", "<C-s>vl", "<Plug>(nvim-surround-visual-line)", { desc = "Surround visual line" })

			-- DELETE / CHANGE
			vim.keymap.set("n", "<C-s>d", "<Plug>(nvim-surround-delete)", { desc = "Delete surround" })
			vim.keymap.set("n", "<C-s>c", "<Plug>(nvim-surround-change)", { desc = "Change surround" })
			-- INSERT MODE
			vim.keymap.set("i", "<C-s>i", "<Plug>(nvim-surround-insert)", { desc = "Surround insert" })
			vim.keymap.set("i", "<C-s>l", "<Plug>(nvim-surround-insert-line)", { desc = "Surround insert line" })

			-- NORMAL MODE
			vim.keymap.set("n", "<C-s>nn", "<Plug>(nvim-surround-normal)", { desc = "Surround normal" })
			vim.keymap.set("n", "<C-s>nc", "<Plug>(nvim-surround-normal-cur)", { desc = "Surround current" })
			vim.keymap.set("n", "<C-s>nl", "<Plug>(nvim-surround-normal-line)", { desc = "Surround line" })
			vim.keymap.set("n", "<C-s>ncl", "<Plug>(nvim-surround-normal-cur-line)", { desc = "Surround current line" })

			-- VISUAL MODE
			vim.keymap.set("x", "<C-s>vv", "<Plug>(nvim-surround-visual)", { desc = "Surround visual" })
			vim.keymap.set("x", "<C-s>vl", "<Plug>(nvim-surround-visual-line)", { desc = "Surround visual line" })

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
			modes = {
				search = { enabled = true },
				char = { enabled = true },
			},
			search = {
				max_range = 10,
			},
		},
		keys = {
			{
				"zk",
				function()
					require("flash").jump()
				end,
				desc = "Flash: Jump",
			},
			{
				"zK",
				function()
					require("flash").treesitter()
				end,
				desc = "Flash: Treesitter jump",
			},
			{
				"<leader>kr",
				function()
					require("flash").remote()
				end,
				mode = "o",
				desc = "Flash: Remote (operator)",
			},
			{
				"<leader>kv",
				function()
					require("flash").treesitter_search()
				end,
				desc = "Flash: TS Search",
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

			vim.keymap.set("n", "<leader>mt", "<cmd>MarksToggleSigns<CR>", { desc = "Marks: toggle signs" })

			vim.keymap.set("n", "<leader>ml", "<cmd>MarksListBuf<CR>", { desc = "Marks: list buffer" })
			vim.keymap.set("n", "<leader>mg", "<cmd>MarksListGlobal<CR>", { desc = "Marks: list global" })

			vim.keymap.set("n", "<leader>mv", "<Plug>(Marks-preview)", { desc = "Marks: preview (float)" })
			vim.keymap.set("n", "<leader>mc", "<Plug>(Marks-deletebuf)", { desc = "Marks: clear buffer marks" })

			vim.keymap.set("n", "]m", "<Plug>(Marks-next)", { desc = "Marks: next" })
			vim.keymap.set("n", "[m", "<Plug>(Marks-prev)", { desc = "Marks: prev" })
		end,
	},

	{
		"Civitasv/cmake-tools.nvim",
		opts = {
			config = function()
				local osys = require("cmake-tools.osys")
				require("cmake-tools").setup({
					cmake_command = "cmake",
					ctest_command = "ctest",
					cmake_use_preset = true,
					cmake_regenerate_on_save = false,
					cmake_generate_options = { "-DCMAKE_EXPORT_COMPILE_COMMANDS=1" },
					cmake_build_options = {}, -- this will be passed when invoke `CMakeBuild`
					-- support macro expansion:
					--       ${kit}
					--       ${kitGenerator}
					--       ${variant:xx}
					cmake_build_directory = function()
						if osys.iswin32 then
							return "out\\${variant:buildType}"
						end
						return "out/${variant:buildType}"
					end, -- this is used to specify generate directory for cmake, allows macro expansion, can be a string or a function returning the string, relative to cwd.
					cmake_compile_commands_options = {
						action = "soft_link", -- available options: soft_link, copy, lsp, none
						-- soft_link: this will automatically make a soft link from compile commands file to target
						-- copy:      this will automatically copy compile commands file to target
						-- lsp:       this will automatically set compile commands file location using lsp
						-- none:      this will make this option ignored
						target = vim.loop.cwd(), -- path to directory, this is used only if action == "soft_link" or action == "copy"
					},
					cmake_kits_path = nil, -- this is used to specify global cmake kits path, see CMakeKits for detailed usage
					cmake_variants_message = {
						short = { show = true }, -- whether to show short message
						long = { show = true, max_length = 40 }, -- whether to show long message
					},
					cmake_dap_configuration = { -- debug settings for cmake
						name = "cpp",
						type = "codelldb",
						request = "launch",
						stopOnEntry = false,
						runInTerminal = true,
						console = "integratedTerminal",
					},
					cmake_executor = { -- executor to use
						name = "quickfix", -- name of the executor
						opts = {}, -- the options the executor will get, possible values depend on the executor type. See `default_opts` for possible values.
						default_opts = { -- a list of default and possible values for executors
							quickfix = {
								show = "always", -- "always", "only_on_error"
								position = "belowright", -- "vertical", "horizontal", "leftabove", "aboveleft", "rightbelow", "belowright", "topleft", "botright", use `:h vertical` for example to see help on them
								size = 10,
								encoding = "utf-8", -- if encoding is not "utf-8", it will be converted to "utf-8" using `vim.fn.iconv`
								auto_close_when_success = true, -- typically, you can use it with the "always" option; it will auto-close the quickfix buffer if the execution is successful.
							},
							toggleterm = {
								direction = "float", -- 'vertical' | 'horizontal' | 'tab' | 'float'
								close_on_exit = false, -- whether close the terminal when exit
								auto_scroll = true, -- whether auto scroll to the bottom
								singleton = true, -- single instance, autocloses the opened one, if present
							},
							overseer = {
								new_task_opts = {
									strategy = {
										"toggleterm",
										direction = "horizontal",
										auto_scroll = true,
										quit_on_exit = "success",
									},
								}, -- options to pass into the `overseer.new_task` command
								on_new_task = function(task)
									require("overseer").open({ enter = false, direction = "right" })
								end, -- a function that gets overseer.Task when it is created, before calling `task:start`
							},
							terminal = {
								name = "Main Terminal",
								prefix_name = "[CMakeTools]: ", -- This must be included and must be unique, otherwise the terminals will not work. Do not use a simple spacebar " ", or any generic name
								split_direction = "horizontal", -- "horizontal", "vertical"
								split_size = 11,

								-- Window handling
								single_terminal_per_instance = true, -- Single viewport, multiple windows
								single_terminal_per_tab = true, -- Single viewport per tab
								keep_terminal_static_location = true, -- Static location of the viewport if avialable
								auto_resize = true, -- Resize the terminal if it already exists

								-- Running Tasks
								start_insert = false, -- If you want to enter terminal with :startinsert upon using :CMakeRun
								focus = false, -- Focus on terminal when cmake task is launched.
								do_not_add_newline = false, -- Do not hit enter on the command inserted when using :CMakeRun, allowing a chance to review or modify the command before hitting enter.
							}, -- terminal executor uses the values in cmake_terminal
						},
					},
					cmake_runner = { -- runner to use
						name = "terminal", -- name of the runner
						opts = {}, -- the options the runner will get, possible values depend on the runner type. See `default_opts` for possible values.
						default_opts = { -- a list of default and possible values for runners
							quickfix = {
								show = "always", -- "always", "only_on_error"
								position = "belowright", -- "bottom", "top"
								size = 10,
								encoding = "utf-8",
								auto_close_when_success = true, -- typically, you can use it with the "always" option; it will auto-close the quickfix buffer if the execution is successful.
							},
							toggleterm = {
								direction = "float", -- 'vertical' | 'horizontal' | 'tab' | 'float'
								close_on_exit = false, -- whether close the terminal when exit
								auto_scroll = true, -- whether auto scroll to the bottom
								singleton = true, -- single instance, autocloses the opened one, if present
							},
							overseer = {
								new_task_opts = {
									strategy = {
										"toggleterm",
										direction = "horizontal",
										autos_croll = true,
										quit_on_exit = "success",
									},
								}, -- options to pass into the `overseer.new_task` command
								on_new_task = function(task) end, -- a function that gets overseer.Task when it is created, before calling `task:start`
							},
							terminal = {
								name = "Main Terminal",
								prefix_name = "[CMakeTools]: ", -- This must be included and must be unique, otherwise the terminals will not work. Do not use a simple spacebar " ", or any generic name
								split_direction = "horizontal", -- "horizontal", "vertical"
								split_size = 11,

								-- Window handling
								single_terminal_per_instance = true, -- Single viewport, multiple windows
								single_terminal_per_tab = true, -- Single viewport per tab
								keep_terminal_static_location = true, -- Static location of the viewport if avialable
								auto_resize = true, -- Resize the terminal if it already exists

								-- Running Tasks
								start_insert = false, -- If you want to enter terminal with :startinsert upon using :CMakeRun
								focus = false, -- Focus on terminal when cmake task is launched.
								do_not_add_newline = false, -- Do not hit enter on the command inserted when using :CMakeRun, allowing a chance to review or modify the command before hitting enter.
								use_shell_alias = false, -- Hide the verbose command wrapper by using a shell alias, showing only the program's output (currently not supported on Windows)
							},
						},
					},
					cmake_notifications = {
						runner = { enabled = true },
						executor = { enabled = true },
						spinner = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }, -- icons used for progress display
						refresh_rate_ms = 100, -- how often to iterate icons
					},
					cmake_virtual_text_support = true, -- Show the target related to current file using virtual text (at right corner)
					cmake_use_scratch_buffer = false, -- A buffer that shows what cmake-tools has done
				})
			end,
		},
	},
}
