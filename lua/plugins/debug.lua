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
				local sep = package.config:sub(1, 1)
				return table.concat({ ... }, sep)
			end

			local function file_exists(p)
				return p and uv.fs_stat(p) ~= nil
			end

			local function is_dir(p)
				local st = p and uv.fs_stat(p)
				return st and st.type == "directory"
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

			local function workspace_root()
				return vim.fn.getcwd()
			end

			local function workspace_key()
				return workspace_root()
			end

			local state = {
				last_executable_by_ws = {},
				last_build_dir_by_ws   = {},
				last_cwd_by_ws         = {},
				last_target_by_ws      = {},
			}

			local function set_last_executable(p)
				state.last_executable_by_ws[workspace_key()] = p
			end

			local function get_last_executable()
				return state.last_executable_by_ws[workspace_key()]
			end

			local function set_last_build_dir(p)
				state.last_build_dir_by_ws[workspace_key()] = p
			end

			local function get_last_build_dir()
				return state.last_build_dir_by_ws[workspace_key()]
			end

			local function set_last_cwd(p)
				state.last_cwd_by_ws[workspace_key()] = p
			end

			local function get_last_cwd()
				return state.last_cwd_by_ws[workspace_key()]
			end

			local function set_last_target(t)
				state.last_target_by_ws[workspace_key()] = t
			end

			local function get_last_target()
				return state.last_target_by_ws[workspace_key()]
			end

			-- Better executable heuristic
			local function is_probably_executable(p)
				if not p or p == "" then
					return false
				end

				if p:match("[/\\]CMakeFiles[/\\]") then
					return false
				end

				-- Common non-executables / build junk
				if p:match("%.a$") or p:match("%.o$") or p:match("%.obj$") then
					return false
				end
				if p:match("%.so$") or p:match("%.so%.") or p:match("%.dylib$") or p:match("%.dll$") then
					return false
				end
				if p:match("%.pdb$") or p:match("%.ilk$") or p:match("%.lib$") or p:match("%.exp$") then
					return false
				end
				if p:match("%.cmake$") or p:match("%.ninja$") or p:match("CMakeCache%.txt$") then
					return false
				end

				local st = uv.fs_stat(p)
				if not st or st.type ~= "file" then
					return false
				end

				if is_windows() then
					return p:lower():match("%.exe$") ~= nil
				end

				if st.mode then
					-- Any execute bit set
					return (st.mode % 512) >= 64 or (st.mode % 64) >= 8 or (st.mode % 8) >= 1
				end

				return false
			end

			local function notify(msg, level)
				vim.notify(msg, level or vim.log.levels.INFO, { title = "DAP" })
			end

			-- -------------------------
			-- DAP signs
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
			-- Prompts: args + env + cwd
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

			local function pick_cwd(default_exe)
				local ws = workspace_root()
				local exe_dir = default_exe and vim.fn.fnamemodify(default_exe, ":p:h") or ws
				local build_dir = get_last_build_dir() or ws

				local choices = {
					{ label = "Workspace root", value = ws },
					{ label = "Executable dir", value = exe_dir },
					{ label = "Build dir", value = build_dir },
					{ label = "Custom...", value = "__custom__" },
				}

				local labels = {}
				for _, item in ipairs(choices) do
					table.insert(labels, item.label .. "  ->  " .. item.value)
				end

				local selected = nil
				vim.ui.select(labels, { prompt = "Select working directory:" }, function(choice)
					selected = choice
				end)

				vim.wait(2000, function()
					return selected ~= nil
				end, 25)

				if not selected then
					local fallback = get_last_cwd() or ws
					set_last_cwd(fallback)
					return fallback
				end

				local idx = nil
				for i, label in ipairs(labels) do
					if label == selected then
						idx = i
						break
					end
				end

				local picked = idx and choices[idx] or choices[1]
				local value = picked.value

				if value == "__custom__" then
					value = vim.fn.input("CWD: ", get_last_cwd() or ws, "dir")
				end

				value = vim.fn.fnamemodify(value, ":p")
				set_last_cwd(value)
				return value
			end

			-- -------------------------
			-- CMake helpers
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

				local out_build_glob = vim.fn.glob(path_join(source_dir, "out", "build", "*"), 1, 1)
				for _, d in ipairs(out_build_glob) do
					table.insert(dirs, d)
				end

				local jet_glob = vim.fn.glob(path_join(source_dir, "cmake-build-*"), 1, 1)
				for _, d in ipairs(jet_glob) do
					table.insert(dirs, d)
				end

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

			local function find_existing_build_dirs(source_dir)
				local dirs = get_candidate_build_dirs(source_dir)
				local out = {}
				for _, d in ipairs(dirs) do
					if is_dir(d) then
						table.insert(out, d)
					end
				end
				return out
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

				table.sort(filtered)
				return filtered
			end

			local function pick_build_dir()
				local source_dir = workspace_root()
				local dirs = find_existing_build_dirs(source_dir)

				if #dirs == 0 then
					local fallback = vim.fn.input("Build directory: ", path_join(source_dir, "build"), "dir")
					fallback = vim.fn.fnamemodify(fallback, ":p")
					set_last_build_dir(fallback)
					return fallback
				end

				local last = get_last_build_dir()
				if last and file_exists(last) then
					return last
				end

				if #dirs == 1 then
					set_last_build_dir(dirs[1])
					return dirs[1]
				end

				local choice = nil
				vim.ui.select(dirs, { prompt = "Select build directory:" }, function(item)
					choice = item
				end)

				vim.wait(2000, function()
					return choice ~= nil
				end, 25)

				choice = choice or dirs[1]
				set_last_build_dir(choice)
				return choice
			end

			local function pick_cmake_executable()
				local source_dir = workspace_root()
				local build_dirs = find_existing_build_dirs(source_dir)

				local candidates = {}
				for _, d in ipairs(build_dirs) do
					local exes = find_exes_in_dir(d)
					for _, e in ipairs(exes) do
						table.insert(candidates, e)
					end
				end

				local seen, uniq = {}, {}
				for _, e in ipairs(candidates) do
					if not seen[e] then
						seen[e] = true
						table.insert(uniq, e)
					end
				end

				local last = get_last_executable()
				if last and file_exists(last) then
					return last
				end

				if #uniq == 0 then
					local manual = vim.fn.input("Path to executable: ", source_dir .. "/", "file")
					manual = vim.fn.fnamemodify(manual, ":p")
					if manual ~= "" then
						set_last_executable(manual)
					end
					return manual
				end

				if #uniq == 1 then
					set_last_executable(uniq[1])
					return uniq[1]
				end

				local choice = nil
				vim.ui.select(uniq, { prompt = "Select executable to debug:" }, function(item)
					choice = item
				end)

				vim.wait(2000, function()
					return choice ~= nil
				end, 25)

				choice = choice or uniq[1]
				set_last_executable(choice)
				return choice
			end

			local function pick_target()
				local last = get_last_target()
				local suggestion = last or ""
				local target = vim.fn.input("CMake target (empty = default/all): ", suggestion)
				target = vim.trim(target or "")
				set_last_target(target)
				return target
			end

			local function build_cmake_target(opts)
				opts = opts or {}

				local build_dir = opts.build_dir or pick_build_dir()
				if not build_dir or build_dir == "" then
					notify("No build directory selected", vim.log.levels.ERROR)
					return false
				end

				set_last_build_dir(build_dir)

				local target = opts.target
				if target == nil then
					target = pick_target()
				end

				local cmd = { "cmake", "--build", build_dir }

				if target and target ~= "" then
					vim.list_extend(cmd, { "--target", target })
				end

				-- Multi-config generators often need this.
				vim.list_extend(cmd, { "--config", "Debug" })

				notify("Building: " .. table.concat(cmd, " "))

				local result = vim.system(cmd, { text = true }):wait()

				if result.code ~= 0 then
					local output = (result.stderr and result.stderr ~= "" and result.stderr) or result.stdout or ""
					notify("Build failed\n" .. output, vim.log.levels.ERROR)
					return false
				end

				notify("Build succeeded")
				return true
			end

			local function build_then_pick_executable()
				local ok = build_cmake_target({})
				if not ok then
					error("Build failed")
				end

				local exe = pick_cmake_executable()
				if exe and exe ~= "" then
					set_last_executable(exe)
				end
				return exe
			end

			local function last_or_pick_executable()
				local exe = get_last_executable()
				if exe and file_exists(exe) then
					return exe
				end
				return pick_cmake_executable()
			end

			local function cwd_from_last_or_pick()
				local exe = get_last_executable()
				local cwd = get_last_cwd()

				if cwd and is_dir(cwd) then
					return cwd
				end

				return pick_cwd(exe)
			end

			-- -------------------------
			-- Configurations: C / C++
			-- -------------------------
			dap.configurations.cpp = {
				{
					name = "Build + Launch (CMake auto-detect)",
					type = "codelldb",
					request = "launch",
					program = build_then_pick_executable,
					cwd = function()
						local exe = get_last_executable()
						return pick_cwd(exe)
					end,
					stopOnEntry = false,
					args = {},
					env = vim.empty_dict(),
					runInTerminal = true,
				},
				{
					name = "Launch (last executable)",
					type = "codelldb",
					request = "launch",
					program = last_or_pick_executable,
					cwd = cwd_from_last_or_pick,
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
						local p = vim.fn.input("Path to executable: ", workspace_root() .. "/", "file")
						p = vim.fn.fnamemodify(p, ":p")
						if p ~= "" then
							set_last_executable(p)
						end
						return p
					end,
					cwd = function()
						local exe = get_last_executable()
						return pick_cwd(exe)
					end,
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
						local p = vim.fn.input("Path to executable: ", workspace_root() .. "/", "file")
						p = vim.fn.fnamemodify(p, ":p")
						if p ~= "" then
							set_last_executable(p)
						end
						return p
					end,
					cwd = function()
						local exe = get_last_executable()
						return pick_cwd(exe)
					end,
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
					cwd = "${workspaceFolder}",
					args = {},
				},
			}
			dap.configurations.c = dap.configurations.cpp

			-- -------------------------
			-- Keymaps
			-- -------------------------
			local map = vim.keymap.set

			-- Run control
			map("n", "<F5>", dap.continue, { desc = "DAP: Continue/Start" })
			map("n", "<leader>dB", function()
				local ok = build_cmake_target({})
				if ok then
					notify("Build finished")
				end
			end, { desc = "DAP: Build CMake target" })

			map("n", "<leader>ds", dap.run_last, { desc = "DAP: Run Last" })
			map("n", "<leader>dt", dap.terminate, { desc = "DAP: Terminate" })

			-- Stepping
			map("n", "<F1>", dap.step_over, { desc = "DAP: Step Over" })
			map("n", "<F2>", dap.step_back, { desc = "DAP: Step Back" })
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

			map("n", "<leader>dc", function()
				local exe = get_last_executable()
				local cwd = pick_cwd(exe)
				if cwd and cwd ~= "" then
					set_last_cwd(cwd)
					notify("CWD set to: " .. cwd)
				end
			end, { desc = "DAP: Pick CWD" })
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
	-- Inline virtual text
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
	-- Telescope integration
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
	-- Persistent breakpoints
	-- ------------------------------------------------------------
	{
		"Weissle/persistent-breakpoints.nvim",
		event = "VeryLazy",
		opts = {
			load_breakpoints_event = { "BufReadPost" },
		},
		config = function(_, opts)
			require("persistent-breakpoints").setup(opts)

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
