return {
	{
		"williamboman/mason.nvim",
		opts = {},
	},

	{
		"jay-babu/mason-nvim-dap.nvim",
		dependencies = {
			"williamboman/mason.nvim",
			"mfussenegger/nvim-dap",
		},
		opts = {
			ensure_installed = { "codelldb" },
			automatic_installation = false,
		},
	},

	{
		"mfussenegger/nvim-dap",
		dependencies = {
			"rcarriga/nvim-dap-ui",
			"nvim-neotest/nvim-nio",
			"theHamsta/nvim-dap-virtual-text",
			"williamboman/mason.nvim",
			"jay-babu/mason-nvim-dap.nvim",
		},
		config = function()
			local dap = require("dap")
			local dapui = require("dapui")
			local widgets = require("dap.ui.widgets")
			local uv = vim.uv or vim.loop

			local function notify(msg, level)
				vim.notify(msg, level or vim.log.levels.INFO, { title = "DAP" })
			end

			local function is_windows()
				local uname = uv.os_uname()
				return uname and uname.sysname and uname.sysname:match("Windows") ~= nil
			end

			local function path_join(...)
				local sep = package.config:sub(1, 1)
				return table.concat({ ... }, sep)
			end

			local function normalize(path)
				if not path or path == "" then
					return nil
				end
				return vim.fn.fnamemodify(path, ":p")
			end

			local function file_exists(path)
				return type(path) == "string" and uv.fs_stat(path) ~= nil
			end

			local function dir_exists(path)
				if type(path) ~= "string" then
					return false
				end
				local stat = uv.fs_stat(path)
				return stat and stat.type == "directory"
			end

			local function executable_exists(bin)
				return vim.fn.executable(bin) == 1
			end

			local function project_root()
				local buf = vim.api.nvim_buf_get_name(0)
				local start = (buf ~= "" and vim.fs.dirname(buf)) or uv.cwd()

				local root = vim.fs.root(start, {
					"CMakePresets.json",
					"CMakeLists.txt",
					".git",
				})

				return normalize(root or uv.cwd())
			end

			local function project_id()
				local root = project_root() or "default"
				return root:gsub("[:/\\]", "_")
			end

			local function state_file()
				return path_join(vim.fn.stdpath("state"), "dap_cpp_state_" .. project_id() .. ".json")
			end

			local default_state = {
				executable = nil,
				cwd = nil,
				args = {},
				env = vim.empty_dict(),
				build_dir = nil,
				target = nil,
			}

			local state = vim.deepcopy(default_state)
			local loaded_project = nil

			local function reset_state()
				state = vim.deepcopy(default_state)
			end

			local function load_state()
				local file = state_file()
				if not file_exists(file) then
					return
				end

				local ok_read, lines = pcall(vim.fn.readfile, file)
				if not ok_read or not lines then
					return
				end

				local ok_json, decoded = pcall(vim.json.decode, table.concat(lines, "\n"))
				if not ok_json or type(decoded) ~= "table" then
					return
				end

				state = vim.tbl_deep_extend("force", state, decoded)
			end

			local function save_state()
				local ok_json, encoded = pcall(vim.json.encode, state)
				if not ok_json then
					return
				end

				vim.fn.mkdir(vim.fn.stdpath("state"), "p")
				pcall(vim.fn.writefile, { encoded }, state_file())
			end

			local function ensure_project_state_loaded()
				local root = project_root() or "default"
				if loaded_project == root then
					return
				end

				reset_state()
				load_state()
				loaded_project = root
			end

			local function default_build_dir()
				ensure_project_state_loaded()
				return normalize(path_join(project_root(), "build"))
			end

			local function choose_build_dir()
				ensure_project_state_loaded()

				local current = state.build_dir
				if current and dir_exists(current) then
					return current
				end

				local picked = vim.fn.input("Build dir: ", default_build_dir(), "dir")
				picked = normalize(picked)

				if picked and picked ~= "" then
					state.build_dir = picked
					save_state()
					return picked
				end

				notify("Geen build directory gekozen", vim.log.levels.WARN)
				return nil
			end

			local function choose_executable()
				ensure_project_state_loaded()

				local initial = state.executable or (project_root() .. (is_windows() and "\\" or "/"))
				local picked = vim.fn.input("Executable: ", initial, "file")
				picked = normalize(picked)

				if not picked or picked == "" then
					notify("Geen executable gekozen", vim.log.levels.WARN)
					return nil
				end

				if not file_exists(picked) then
					notify("Executable bestaat niet: " .. picked, vim.log.levels.ERROR)
					return nil
				end

				state.executable = picked
				save_state()
				return picked
			end

			local function parse_args(raw)
				raw = vim.trim(raw or "")
				if raw == "" then
					return {}
				end

				local args = {}
				for part in raw:gmatch([["[^"]*"|'[^']*'|%S+]]) do
					part = part:gsub([[^"(.*)"$]], "%1")
					part = part:gsub([[^'(.*)'$]], "%1")
					table.insert(args, part)
				end
				return args
			end

			local function input_args()
				ensure_project_state_loaded()

				local initial = table.concat(state.args or {}, " ")
				local raw = vim.fn.input("Args: ", initial)

				if raw == nil then
					return state.args or {}
				end

				local args = parse_args(raw)
				state.args = args
				save_state()
				return args
			end

			local function input_env()
				ensure_project_state_loaded()

				local items = {}
				for k, v in pairs(state.env or {}) do
					items[#items + 1] = string.format("%s=%s", k, v)
				end
				table.sort(items)

				local raw = vim.fn.input("Env KEY=VAL;KEY=VAL: ", table.concat(items, ";"))
				if raw == nil then
					return state.env or vim.empty_dict()
				end

				raw = vim.trim(raw)
				if raw == "" then
					state.env = vim.empty_dict()
					save_state()
					return vim.empty_dict()
				end

				local env = vim.empty_dict()
				for pair in raw:gmatch("[^;]+") do
					local k, v = pair:match("^%s*([^=]+)%s*=%s*(.-)%s*$")
					if k and v then
						env[k] = v
					end
				end

				state.env = env
				save_state()
				return env
			end

			local function choose_cwd()
				ensure_project_state_loaded()

				local root = project_root()
				local exe_dir = state.executable and vim.fn.fnamemodify(state.executable, ":p:h") or root
				local build_dir = state.build_dir or default_build_dir()

				local options = {
					"1. Project root: " .. root,
					"2. Executable dir: " .. exe_dir,
					"3. Build dir: " .. build_dir,
					"4. Custom",
				}

				local choice = vim.fn.inputlist(vim.list_extend({ "Choose CWD:" }, options))

				local cwd = nil
				if choice == 1 then
					cwd = root
				elseif choice == 2 then
					cwd = exe_dir
				elseif choice == 3 then
					cwd = build_dir
				elseif choice == 4 then
					cwd = vim.fn.input("CWD: ", state.cwd or root, "dir")
				end

				cwd = normalize(cwd)
				if not cwd or cwd == "" then
					notify("Geen geldige CWD gekozen", vim.log.levels.WARN)
					return state.cwd or root
				end

				state.cwd = cwd
				save_state()
				return cwd
			end

			local function current_cwd()
				ensure_project_state_loaded()

				if state.cwd and dir_exists(state.cwd) then
					return state.cwd
				end

				return project_root()
			end

			local function ensure_executable()
				ensure_project_state_loaded()

				if state.executable and file_exists(state.executable) then
					return state.executable
				end

				return choose_executable()
			end

			local function current_args()
				ensure_project_state_loaded()
				return state.args or {}
			end

			local function current_env()
				ensure_project_state_loaded()
				return state.env or {}
			end

			local function build_target_name()
				ensure_project_state_loaded()

				local target = vim.fn.input("Target (empty = default): ", state.target or "")
				target = vim.trim(target or "")

				if target == "" then
					state.target = nil
					save_state()
					return nil
				end

				state.target = target
				save_state()
				return target
			end

			local function cmake_build(target, on_exit)
				ensure_project_state_loaded()

				if not executable_exists("cmake") then
					notify("cmake niet gevonden in PATH", vim.log.levels.ERROR)
					if on_exit then
						on_exit(false)
					end
					return
				end

				local build_dir = choose_build_dir()
				if not build_dir then
					if on_exit then
						on_exit(false)
					end
					return
				end

				local cmd = { "cmake", "--build", build_dir }
				if target and target ~= "" then
					vim.list_extend(cmd, { "--target", target })
					state.target = target
					save_state()
				end

				notify("Build gestart: " .. table.concat(cmd, " "))

				vim.fn.jobstart(cmd, {
					stdout_buffered = false,
					stderr_buffered = false,
					on_stdout = function(_, data)
						if not data then
							return
						end
						for _, line in ipairs(data) do
							if line ~= "" then
								vim.schedule(function()
									vim.api.nvim_echo({ { line } }, false, {})
								end)
							end
						end
					end,
					on_stderr = function(_, data)
						if not data then
							return
						end
						for _, line in ipairs(data) do
							if line ~= "" then
								vim.schedule(function()
									vim.api.nvim_echo({ { line, "WarningMsg" } }, false, {})
								end)
							end
						end
					end,
					on_exit = function(_, code)
						vim.schedule(function()
							if code == 0 then
								notify("Build gelukt")
								if on_exit then
									on_exit(true)
								end
							else
								notify("Build gefaald", vim.log.levels.ERROR)
								if on_exit then
									on_exit(false)
								end
							end
						end)
					end,
				})
			end

			local function validation_env()
				ensure_project_state_loaded()

				local env = vim.tbl_extend("force", {}, state.env or {})
				env.VK_INSTANCE_LAYERS = "VK_LAYER_KHRONOS_validation"

				if os.getenv("VK_LAYER_PATH") then
					env.VK_LAYER_PATH = os.getenv("VK_LAYER_PATH")
				end

				return env
			end

			ensure_project_state_loaded()

			local mason_root = path_join(vim.fn.stdpath("data"), "mason", "packages", "codelldb", "extension")
			local adapter = path_join(mason_root, "adapter", is_windows() and "codelldb.exe" or "codelldb")

			if not file_exists(adapter) then
				notify("CodeLLDB niet gevonden via Mason: " .. adapter, vim.log.levels.WARN)
			end

			dap.adapters.codelldb = {
				type = "server",
				port = "${port}",
				executable = {
					command = adapter,
					args = { "--port", "${port}" },
				},
			}

			local launch_base = {
				type = "codelldb",
				request = "launch",
				cwd = current_cwd,
				args = current_args,
				runInTerminal = true,
				stopOnEntry = false,
			}

			dap.configurations.cpp = {
				vim.tbl_extend("force", {}, launch_base, {
					name = "Launch executable",
					program = ensure_executable,
					env = current_env,
				}),
				vim.tbl_extend("force", {}, launch_base, {
					name = "Launch with Vulkan validation",
					program = ensure_executable,
					env = validation_env,
				}),
				{
					name = "Attach process",
					type = "codelldb",
					request = "attach",
					pid = require("dap.utils").pick_process,
					cwd = current_cwd,
				},
			}

			dap.configurations.c = dap.configurations.cpp

			vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticError" })
			vim.fn.sign_define("DapBreakpointCondition", { text = "◆", texthl = "DiagnosticWarn" })
			vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DiagnosticWarn", linehl = "Visual" })
			vim.fn.sign_define("DapLogPoint", { text = "◉", texthl = "DiagnosticInfo" })

			dapui.setup({
				layouts = {
					{
						elements = {
							{ id = "scopes", size = 0.50 },
							{ id = "stacks", size = 0.20 },
							{ id = "breakpoints", size = 0.15 },
							{ id = "watches", size = 0.15 },
						},
						size = 42,
						position = "left",
					},
					{
						elements = {
							{ id = "repl", size = 1.0 },
						},
						size = 0.25,
						position = "bottom",
					},
				},
				controls = {
					enabled = true,
					element = "repl",
				},
			})

			dap.listeners.after.event_initialized["dapui_auto_open"] = function()
				dapui.open()
			end
			dap.listeners.before.event_terminated["dapui_auto_close"] = function()
				dapui.close()
			end
			dap.listeners.before.event_exited["dapui_auto_close"] = function()
				dapui.close()
			end

			require("nvim-dap-virtual-text").setup({
				commented = true,
				virt_text_pos = "eol",
			})

			local map = vim.keymap.set

			-- Core debugging
			map("n", "<F1>", dap.step_into, { desc = "DAP Step into" })
			map("n", "<F2>", dap.step_out, { desc = "DAP Step out" })
			map("n", "<F3>", dap.step_over, { desc = "DAP Step over" })
			map("n", "<F4>", function()
				dapui.float_element("watches", { enter = true })
			end, { desc = "DAP watches" })
			map("n", "<F5>", dap.continue, { desc = "DAP Continue" })
			map("n", "<F6>", dap.run_last, { desc = "DAP Run last" })

			-- Debug UI / inspect
			map("n", "<leader>du", dapui.toggle, { desc = "DAP UI toggle" })
			map("n", "<leader>dr", dap.repl.open, { desc = "DAP REPL" })

			map({ "n", "v" }, "<leader>de", function()
				widgets.hover()
			end, { desc = "DAP Hover eval" })

			map({ "n", "v" }, "<leader>dE", function()
				widgets.preview()
			end, { desc = "DAP Preview eval" })

			map("n", "<leader>ds", function()
				widgets.centered_float(widgets.scopes)
			end, { desc = "DAP Scopes float" })

			-- Breakpoints / flow
			map("n", "<leader>dc", dap.run_to_cursor, { desc = "DAP Run to cursor" })

			-- Stack navigation
			map("n", "<leader>dj", dap.down, { desc = "DAP Down stack" })
			map("n", "<leader>dk", dap.up, { desc = "DAP Up stack" })
			map("n", "<leader>d.", dap.focus_frame, { desc = "DAP Focus frame" })

			-- Session config
			map("n", "<leader>df", function()
				local exe = choose_executable()
				if exe then
					notify("Executable: " .. exe)
				end
			end, { desc = "DAP Executable" })

			map("n", "<leader>da", function()
				input_args()
			end, { desc = "DAP Args" })

			map("n", "<leader>dv", function()
				input_env()
			end, { desc = "DAP Env" })

			map("n", "<leader>d?", function()
				local bps = require("dap.breakpoints").get()
				local qf = {}
				for bufnr, buf_bps in pairs(bps) do
					for _, bp in ipairs(buf_bps) do
						table.insert(qf, {
							bufnr = bufnr,
							lnum = bp.line,
							text = "Breakpoint",
						})
					end
				end
				vim.fn.setqflist(qf)
				vim.cmd("copen")
			end, { desc = "List breakpoints (quickfix)" })

			vim.keymap.set("n", "<leader>dO", "<cmd>Telescope dap configurations<CR>", {
				desc = "DAP Configurations",
			})

			vim.keymap.set("n", "<leader>dV", "<cmd>Telescope dap variables<CR>", {
				desc = "DAP Variables",
			})
			map("n", "<leader>dq", dap.terminate, { desc = "DAP Quit" })
			map("n", "<leader>dR", dap.restart, { desc = "DAP Restart" })
		end,
	},

	{
		"nvim-telescope/telescope-dap.nvim",
		dependencies = {
			"nvim-telescope/telescope.nvim",
			"mfussenegger/nvim-dap",
		},
		config = function()
			local ok, telescope = pcall(require, "telescope")
			if ok then
				pcall(telescope.load_extension, "dap")
			end

			vim.keymap.set("n", "<leader>do", "<cmd>Telescope dap frames<CR>", { desc = "DAP Stack frames" })
			vim.keymap.set("n", "<leader>dh", "<cmd>Telescope dap commands<CR>", { desc = "DAP Commands" })
		end,
	},

	{
		"Weissle/persistent-breakpoints.nvim",
		lazy = false,
		config = function()
			local pb = require("persistent-breakpoints")
			local api = require("persistent-breakpoints.api")

			pb.setup({
				load_breakpoints_event = { "BufReadPost" },
			})

			local map = vim.keymap.set

			map("n", "<F8>", api.toggle_breakpoint, { desc = "DAP Breakpoint" })
			map("n", "<leader>db", api.set_conditional_breakpoint, { desc = "DAP Conditional breakpoint" })
			map("n", "<leader>dl", api.set_log_point, { desc = "DAP Log point" })

			map("n", "<leader>dS", api.store_breakpoints, { desc = "DAP Save breakpoints" })
			map("n", "<leader>dL", api.load_breakpoints, { desc = "DAP Load breakpoints" })
			map("n", "<leader>dX", api.clear_all_breakpoints, { desc = "DAP Clear breakpoints" })
		end,
	},
}
