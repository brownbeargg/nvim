return {
	-- ------------------------------------------------------------
	-- Installer + DAP adapter installer
	-- ------------------------------------------------------------
	{
		"williamboman/mason.nvim",
		opts = {},
	},

	{
		"jay-babu/mason-nvim-dap.nvim",
		dependencies = { "williamboman/mason.nvim", "mfussenegger/nvim-dap" },
		opts = {
			automatic_setup = true,
			ensure_installed = {
				"codelldb",
				"cppdbg",
			},
		},
	},

	-- ------------------------------------------------------------
	-- Core DAP
	-- ------------------------------------------------------------
	{
		"mfussenegger/nvim-dap",
		dependencies = {
			"williamboman/mason.nvim",
			"jay-babu/mason-nvim-dap.nvim",
		},
		config = function()
			local dap = require("dap")
			local uv = vim.uv or vim.loop

			-- -------------------------
			-- Helpers
			-- -------------------------
			local function is_windows()
				return uv.os_uname().sysname:match("Windows") ~= nil
			end

			local function path_join(...)
				local sep = package.config:sub(1, 1) -- "\" on Windows, "/" elsewhere
				return table.concat({ ... }, sep)
			end

			local function file_exists(p)
				return uv.fs_stat(p) ~= nil
			end

			local function read_json_file(p)
				local ok, lines = pcall(vim.fn.readfile, p)
				if not ok or not lines then
					return nil
				end
				local text = table.concat(lines, "\n")
				local ok2, obj = pcall(vim.json.decode, text)
				if not ok2 then
					return nil
				end
				return obj
			end

			local function expand_preset_path(s, source_dir)
				if type(s) ~= "string" then
					return nil
				end
				s = s:gsub("%${sourceDir}", source_dir)
				s = s:gsub("%${workspaceFolder}", source_dir)
				return vim.fn.fnamemodify(s, ":p")
			end

			-- Better executable heuristic (filters build junk)
			local function is_probably_executable(p)
				if not p or p == "" then
					return false
				end
				if p:match("[/\\]CMakeFiles[/\\]") then
					return false
				end

				-- Filter common non-executables
				if p:match("%.a$") or p:match("%.o$") or p:match("%.obj$") then
					return false
				end
				if p:match("%.so") or p:match("%.dylib$") or p:match("%.dll$") then
					return false
				end
				if p:match("%.pdb$") or p:match("%.ilk$") then
					return false
				end

				local st = uv.fs_stat(p)
				if not st or st.type ~= "file" then
					return false
				end

				if is_windows() then
					return p:match("%.exe$") ~= nil
				end

				if st.mode then
					local m = st.mode
					local any_exec = (m % 64) >= 1
					return any_exec or true
				end

				return true
			end

			-- -------------------------
			-- DAP signs (engine-like clarity)
			-- -------------------------
			vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticError" })
			vim.fn.sign_define("DapBreakpointCondition", { text = "◆", texthl = "DiagnosticWarn" })
			vim.fn.sign_define("DapLogPoint", { text = "◉", texthl = "DiagnosticInfo" })
			vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DiagnosticWarn", linehl = "Visual" })

			-- -------------------------
			-- Adapter: CodeLLDB via Mason path
			-- -------------------------
			local mason_root = vim.fn.stdpath("data") .. "/mason"
			local codelldb_exe = path_join(mason_root, "packages", "codelldb", "extension", "adapter", "codelldb")
			if is_windows() then
				codelldb_exe = codelldb_exe .. ".exe"
			end

			dap.adapters.codelldb = {
				type = "server",
				port = "${port}",
				executable = {
					command = codelldb_exe,
					args = { "--port", "${port}" },
				},
			}

			-- -------------------------
			-- Prompts: args + env
			-- -------------------------
			local function pick_args()
				local s = vim.fn.input("Args: ")
				if not s or s == "" then
					return {}
				end
				return vim.fn.split(s, " ", true)
			end

			local function pick_env()
				local s = vim.fn.input("Env (KEY=VAL, comma-separated): ")
				if not s or s == "" then
					return vim.empty_dict()
				end
				local env = vim.empty_dict()
				for kv in s:gmatch("[^,]+") do
					local k, v = kv:match("^%s*([^=]+)%s*=%s*(.-)%s*$")
					if k and v then
						env[k] = v
					end
				end
				return env
			end

			-- -------------------------
			-- CMake executable auto-detect
			-- -------------------------
			local function get_candidate_build_dirs(source_dir)
				local dirs = {}

				local presets_path = path_join(source_dir, "CMakePresets.json")
				if file_exists(presets_path) then
					local presets = read_json_file(presets_path)
					if presets and type(presets.configurePresets) == "table" then
						for _, p in ipairs(presets.configurePresets) do
							local bd = expand_preset_path(p.binaryDir, source_dir)
							if bd and bd ~= "" then
								table.insert(dirs, bd)
							end
						end
					end
				end

				local common = {
					path_join(source_dir, "build"),
					path_join(source_dir, "Build"),
					path_join(source_dir, "out", "build"),
					path_join(source_dir, "cmake-build-debug"),
					path_join(source_dir, "cmake-build-release"),
				}
				for _, d in ipairs(common) do
					table.insert(dirs, d)
				end

				-- VS / multi-config style
				local out_build_glob = vim.fn.glob(path_join(source_dir, "out", "build", "*"), 1, 1)
				for _, d in ipairs(out_build_glob) do
					table.insert(dirs, d)
				end

				-- JetBrains style
				local jet_glob = vim.fn.glob(path_join(source_dir, "cmake-build-*"), 1, 1)
				for _, d in ipairs(jet_glob) do
					table.insert(dirs, d)
				end

				-- Uniq + normalize
				local seen, uniq = {}, {}
				for _, d in ipairs(dirs) do
					d = vim.fn.fnamemodify(d, ":p")
					if d and d ~= "" and not seen[d] then
						seen[d] = true
						table.insert(uniq, d)
					end
				end
				return uniq
			end

			local function find_exes_in_dir(dir)
				local pattern
				if is_windows() then
					pattern = dir .. "/**/*.exe"
				else
					pattern = dir .. "/**/*"
				end
				local matches = vim.fn.glob(pattern, 1, 1)

				local filtered = {}
				for _, p in ipairs(matches) do
					if is_probably_executable(p) then
						table.insert(filtered, vim.fn.fnamemodify(p, ":p"))
					end
				end
				return filtered
			end

			local function pick_cmake_executable()
				local source_dir = vim.fn.getcwd()
				local build_dirs = get_candidate_build_dirs(source_dir)

				local candidates = {}
				for _, d in ipairs(build_dirs) do
					if file_exists(d) then
						local exes = find_exes_in_dir(d)
						for _, e in ipairs(exes) do
							table.insert(candidates, e)
						end
					end
				end

				-- uniq
				local seen, uniq = {}, {}
				for _, e in ipairs(candidates) do
					if not seen[e] then
						seen[e] = true
						table.insert(uniq, e)
					end
				end

				if #uniq == 0 then
					return vim.fn.input("Path to executable: ", source_dir .. "/", "file")
				end

				if #uniq == 1 then
					return uniq[1]
				end

				local choice = nil
				vim.ui.select(uniq, { prompt = "Select executable to debug:" }, function(item)
					choice = item
				end)

				-- Wait briefly for async ui.select result
				vim.wait(1500, function()
					return choice ~= nil
				end, 25)

				return choice or uniq[1]
			end

			-- -------------------------
			-- Configurations: C / C++
			-- -------------------------
			dap.configurations.cpp = {
				{
					name = "Launch (CMake auto-detect)",
					type = "codelldb",
					request = "launch",
					program = pick_cmake_executable,
					cwd = "${workspaceFolder}",
					stopOnEntry = false,
					args = {},
					env = vim.empty_dict(),
					runInTerminal = true,
				},
				{
					name = "Launch (ask executable)",
					type = "codelldb",
					request = "launch",
					program = function()
						return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
					end,
					cwd = "${workspaceFolder}",
					stopOnEntry = false,
					args = {},
					env = vim.empty_dict(),
					runInTerminal = true,
				},
				{
					name = "Launch (custom env/args)",
					type = "codelldb",
					request = "launch",
					program = function()
						return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
					end,
					cwd = "${workspaceFolder}",
					stopOnEntry = false,
					args = pick_args,
					env = pick_env,
					runInTerminal = true,
				},
				{
					name = "Attach (pick process)",
					type = "codelldb",
					request = "attach",
					pid = require("dap.utils").pick_process,
					args = {},
				},
			}
			dap.configurations.c = dap.configurations.cpp

			-- -------------------------
			-- Keymaps (IDE-like)
			-- -------------------------
			local map = vim.keymap.set
			-- Run control
			map("n", "<F5>", dap.continue, { desc = "DAP: Continue/Start" })
			map("n", "<leader>ds", dap.run_last, { desc = "DAP: Run Last" })
			map("n", "<leader>dt", dap.terminate, { desc = "DAP: Terminate" })

			-- Stepping
			map("n", "<F1>", dap.step_over, { desc = "DAP: Step Over (Next)" })
			map("n", "<F3>", dap.step_into, { desc = "DAP: Step Into" })
			map("n", "<leader>do", dap.step_out, { desc = "DAP: Step Out" })

			-- Breakpoints
			map("n", "<F9>", dap.toggle_breakpoint, { desc = "DAP: Toggle Breakpoint" })

			map("n", "<leader>db", function()
				dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
			end, { desc = "DAP: Conditional Breakpoint" })

			map("n", "<leader>dl", function()
				dap.set_breakpoint(nil, nil, vim.fn.input("Log point message: "))
			end, { desc = "DAP: Logpoint" })

			map("n", "<leader>dh", function()
				dap.set_breakpoint(nil, vim.fn.input("Hit count: "))
			end, { desc = "DAP: Hitcount Breakpoint" })

			-- Stack navigation
			map("n", "<leader>du", dap.up, { desc = "DAP: Up Stack" })
			map("n", "<leader>dd", dap.down, { desc = "DAP: Down Stack" })

			-- REPL / Eval
			map("n", "<leader>dr", dap.repl.open, { desc = "DAP: REPL" })

			map({ "n", "v" }, "<leader>de", function()
				local ok, dapui = pcall(require, "dapui")
				if ok then
					dapui.eval()
				end
			end, { desc = "DAP: Eval" })
		end,
	},

	-- ------------------------------------------------------------
	-- DAP UI (panels + auto open/close)
	-- ------------------------------------------------------------
	{
		"rcarriga/nvim-dap-ui",
		dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" },
		config = function()
			local dap = require("dap")
			local dapui = require("dapui")

			dapui.setup({
				layouts = {
					{
						elements = {
							{ id = "scopes", size = 0.40 },
							{ id = "breakpoints", size = 0.15 },
							{ id = "stacks", size = 0.25 },
							{ id = "watches", size = 0.20 },
						},
						size = 45,
						position = "left",
					},
					{
						elements = {
							{ id = "repl", size = 0.40 },
							{ id = "console", size = 0.60 },
						},
						size = 0.30,
						position = "bottom",
					},
				},
				controls = {
					enabled = true,
					element = "repl",
				},
			})

			dap.listeners.after.event_initialized["dapui_config"] = function()
				dapui.open()
			end
			dap.listeners.before.event_terminated["dapui_config"] = function()
				dapui.close()
			end
			dap.listeners.before.event_exited["dapui_config"] = function()
				dapui.close()
			end

			vim.keymap.set("n", "<leader>dU", dapui.toggle, { desc = "DAP: Toggle UI" })
			vim.keymap.set("n", "<leader>dw", function()
				dapui.float_element("watches", { enter = true })
			end, { desc = "DAP: Watches (float)" })
		end,
	},

	-- ------------------------------------------------------------
	-- Inline virtual text (values at end-of-line)
	-- ------------------------------------------------------------
	{
		"theHamsta/nvim-dap-virtual-text",
		dependencies = { "mfussenegger/nvim-dap" },
		opts = {
			commented = true,
			virt_text_pos = "eol",
		},
	},

	-- ------------------------------------------------------------
	-- Telescope integration (amazing for navigation in big codebases)
	-- ------------------------------------------------------------
	{
		"nvim-telescope/telescope-dap.nvim",
		dependencies = { "nvim-telescope/telescope.nvim", "mfussenegger/nvim-dap" },
		config = function()
			local ok, telescope = pcall(require, "telescope")
			if not ok then
				return
			end
			pcall(telescope.load_extension, "dap")

			local map = vim.keymap.set
			map("n", "<leader>df", "<cmd>Telescope dap frames<CR>", { desc = "DAP: Frames (Telescope)" })
			map("n", "<leader>dk", "<cmd>Telescope dap commands<CR>", { desc = "DAP: Commands (Telescope)" })
			map("n", "<leader>dv", "<cmd>Telescope dap variables<CR>", { desc = "DAP: Variables (Telescope)" })
			map("n", "<leader>dpt", "<cmd>Telescope dap list_breakpoints<CR>", { desc = "DAP: Breakpoints (Telescope)" })
		end,
	},

	-- ------------------------------------------------------------
	-- Persistent breakpoints (super useful in engine work)
	-- ------------------------------------------------------------
	{
		"Weissle/persistent-breakpoints.nvim",
		event = "VeryLazy",
		opts = {
			load_breakpoints_event = { "BufReadPost" },
		},
		config = function(_, opts)
			require("persistent-breakpoints").setup(opts)

			-- Optional keymaps (extra power)
			vim.keymap.set("n", "<leader>dps", function()
				require("persistent-breakpoints.api").store_breakpoints()
			end, { desc = "DAP: Store Breakpoints" })

			vim.keymap.set("n", "<leader>dpl", function()
				require("persistent-breakpoints.api").load_breakpoints()
			end, { desc = "DAP: Load Breakpoints" })

			vim.keymap.set("n", "<leader>dpc", function()
				require("persistent-breakpoints.api").clear_all_breakpoints()
			end, { desc = "DAP: Clear All Breakpoints" })
		end,
	},
}
