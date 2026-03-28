return {
	{
		"neovim/nvim-lspconfig",
	},

	{
		"nvimtools/none-ls.nvim",
		dependencies = { "nvim-lua/plenary.nvim" },
		config = function()
			local null_ls = require("null-ls")
			local formatting = null_ls.builtins.formatting
			local diagnostics = null_ls.builtins.diagnostics
			local utils = require("null-ls.utils")

			local GLSL_FTS = { "glsl", "vert", "frag", "geom", "comp", "tesc", "tese" }

			local clang_fts = vim.deepcopy(formatting.clang_format.filetypes or {})
			vim.list_extend(clang_fts, GLSL_FTS)

			local function path_join(...)
				return table.concat({ ... }, package.config:sub(1, 1))
			end

			local function root_has(params, files)
				local root = params and params.root
				if not root or root == "" then
					return false
				end

				for _, f in ipairs(files) do
					if vim.uv.fs_stat(path_join(root, f)) then
						return true
					end
				end

				return false
			end

			local function is_glsl(ft)
				return vim.tbl_contains(GLSL_FTS, ft)
			end

			null_ls.setup({
				debug = false,

				root_dir = utils.root_pattern(
					"compile_commands.json",
					".clang-format",
					"_clang-format",
					".git"
				),

				sources = {
					formatting.stylua,

					diagnostics.selene.with({
						condition = function(params)
							return root_has(params, { "selene.toml", "selene.yml" })
						end,
					}),

					formatting.clang_format.with({
						filetypes = clang_fts,
						extra_args = function(params)
							local args = {}

							if root_has(params, { ".clang-format", "_clang-format" }) then
								table.insert(args, "--style=file")
							end

							if is_glsl(params.ft) then
								table.insert(args, "--assume-filename=shader.glsl")
							end

							return args
						end,
					}),

					diagnostics.glslc.with({
						filetypes = GLSL_FTS,
						extra_args = {
							"-c",
							"-fauto-map-locations",
							"-fauto-bind-uniforms",
						},
					}),
				},
			})

			vim.keymap.set("n", "<leader>lf", function()
				vim.lsp.buf.format({
					filter = function(client)
						return client.name == "null-ls" or client.name == "none-ls"
					end,
					timeout_ms = 10000,
				})
			end, { desc = "Format buffer (none-ls)" })
		end,
	},

	{
		"mfussenegger/nvim-lint",
		config = function()
			local lint = require("lint")

			if lint.linters.cppcheck then
				lint.linters.cppcheck.args = {
					"--enable=warning,style,performance,portability",
					"--inconclusive",
					"--language=c++",
					"--std=c++20",
					"--template=gcc",
				}
				lint.linters.cppcheck.ignore_exitcode = true
			end

			lint.linters_by_ft = {
				c = { "cppcheck" },
				cpp = { "cppcheck" },
			}

			vim.api.nvim_create_autocmd("BufWritePost", {
				callback = function()
					lint.try_lint()
				end,
			})

			vim.keymap.set("n", "<leader>lc", function()
				lint.try_lint()
			end, { desc = "Run cppcheck" })
		end,
	},
}
