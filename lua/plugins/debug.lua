local uv = vim.uv or vim.loop
local path_sep = package.config:sub(1, 1)

local function notify(msg, level)
	vim.notify(msg, level or vim.log.levels.INFO, { title = "DAP" })
end

local function is_windows()
	local uname = uv.os_uname()
	return uname and uname.sysname and uname.sysname:match("Windows") ~= nil
end

local function path_join(...)
	return table.concat({ ... }, path_sep)
end

local function normalize(path)
	if not path or path == "" then
		return nil
	end

	return vim.fn.fnamemodify(path, ":p")
end

local function file_exists(path)
	if type(path) ~= "string" then
		return false
	end

	local stat = uv.fs_stat(path)
	return stat and stat.type ~= "directory"
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
		"compile_commands.json",
		"Makefile",
		"build.zig",
		"Cargo.toml",
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
	return normalize(path_join(project_root(), "build"))
end

local function choose_build_dir()
	ensure_project_state_loaded()

	local initial = state.build_dir or default_build_dir()
	local picked = vim.fn.input("Build dir: ", initial, "dir")
	picked = normalize(picked)

	if not picked or picked == "" then
		notify("No build directory chosen", vim.log.levels.WARN)
		return nil
	end

	state.build_dir = picked
	save_state()

	return picked
end

local function choose_executable()
	ensure_project_state_loaded()

	local initial = state.executable

	if not initial then
		local build_dir = state.build_dir or default_build_dir()
		initial = dir_exists(build_dir) and (build_dir .. path_sep) or (project_root() .. path_sep)
	end

	local picked = vim.fn.input("Executable: ", initial, "file")
	picked = normalize(picked)

	if not picked or picked == "" then
		notify("No executable chosen", vim.log.levels.WARN)
		return nil
	end

	if not file_exists(picked) then
		notify("Executable does not exist: " .. picked, vim.log.levels.ERROR)
		return nil
	end

	state.executable = picked
	save_state()

	notify("Executable: " .. picked)
	return picked
end

local function ensure_executable()
	ensure_project_state_loaded()

	if state.executable and file_exists(state.executable) then
		return state.executable
	end

	return choose_executable()
end

local function executable_dir()
	local exe = ensure_executable()

	if not exe then
		return project_root()
	end

	return vim.fn.fnamemodify(exe, ":p:h")
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

	state.args = parse_args(raw)
	save_state()

	return state.args
end

local function current_args()
	ensure_project_state_loaded()
	return state.args or {}
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

local function current_env()
	ensure_project_state_loaded()
	return state.env or vim.empty_dict()
end

local function validation_env()
	local env = vim.tbl_extend("force", {}, current_env())

	env.VK_INSTANCE_LAYERS = "VK_LAYER_KHRONOS_validation"

	if os.getenv("VK_LAYER_PATH") then
		env.VK_LAYER_PATH = os.getenv("VK_LAYER_PATH")
	end

	return env
end

local function build_target_name()
	ensure_project_state_loaded()

	local target = vim.fn.input("Target empty = default: ", state.target or "")
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

local function build_project(target)
	local root = project_root()
	local jobs = tostring(uv.available_parallelism and uv.available_parallelism() or 4)

	if vim.fn.filereadable(path_join(root, "CMakeLists.txt")) == 1 then
		local build_dir = choose_build_dir()

		if not build_dir then
			return
		end

		local cmd = { "cmake", "--build", build_dir, "--parallel", jobs }

		if target and target ~= "" then
			vim.list_extend(cmd, { "--target", target })
		end

		Snacks.terminal.open(cmd, {
			cwd = root,
			win = { position = "bottom", height = 0.30 },
		})
	elseif vim.fn.filereadable(path_join(root, "Makefile")) == 1 then
		Snacks.terminal.open({ "make", "-j", jobs }, {
			cwd = root,
			win = { position = "bottom", height = 0.30 },
		})
	else
		notify("No CMakeLists.txt or Makefile found in project root", vim.log.levels.WARN)
	end
end

local function run_executable()
	local exe = ensure_executable()

	if not exe then
		return
	end

	local cmd = { exe }
	vim.list_extend(cmd, current_args())

	Snacks.terminal.open(cmd, {
		cwd = executable_dir(),
		win = { position = "bottom", height = 0.30 },
	})
end

return {
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
		"Weissle/persistent-breakpoints.nvim",
		lazy = false,
		config = function()
			local pb = require("persistent-breakpoints")

			pb.setup({
				load_breakpoints_event = { "BufReadPost" },
			})

			local api = require("persistent-breakpoints.api")
			local map = vim.keymap.set

			map("n", "<F8>", api.toggle_breakpoint, { desc = "DAP Breakpoint" })
			map("n", "<leader>db", api.set_conditional_breakpoint, { desc = "DAP Conditional breakpoint" })
			map("n", "<leader>dl", api.set_log_point, { desc = "DAP Log point" })

			map("n", "<leader>dS", api.store_breakpoints, { desc = "DAP Save breakpoints" })
			map("n", "<leader>dL", api.load_breakpoints, { desc = "DAP Load breakpoints" })
			map("n", "<leader>dX", api.clear_all_breakpoints, { desc = "DAP Clear breakpoints" })
		end,
	},

	{
		"mfussenegger/nvim-dap",
		dependencies = {
			"williamboman/mason.nvim",
			"jay-babu/mason-nvim-dap.nvim",
			"rcarriga/nvim-dap-ui",
			"nvim-neotest/nvim-nio",
			"theHamsta/nvim-dap-virtual-text",
			{ "Weissle/persistent-breakpoints.nvim", lazy = false },
		},
		keys = {
			{
				"<F1>",
				function()
					require("dap").step_into()
				end,
				desc = "Step into",
			},
			{
				"<F2>",
				function()
					require("dap").step_over()
				end,
				desc = "Step over",
			},
			{
				"<F3>",
				function()
					require("dap").step_out()
				end,
				desc = "Step out",
			},
			{
				"<F4>",
				function()
					require("dapui").float_element("watches", { enter = true })
				end,
				desc = "Watches",
			},
			{
				"<F5>",
				function()
					require("dap").continue()
				end,
				desc = "Continue/start",
			},
			{
				"<F6>",
				function()
					require("dap").run_last()
				end,
				desc = "Run last",
			},

			{
				"<F8>",
				function()
					require("persistent-breakpoints.api").toggle_breakpoint()
				end,
				desc = "Toggle breakpoint",
			},

			{
				"<leader>df",
				function()
					choose_executable()
				end,
				desc = "Choose executable",
			},
			{
				"<leader>da",
				function()
					input_args()
				end,
				desc = "Set args",
			},
			{
				"<leader>dv",
				function()
					input_env()
				end,
				desc = "Set env",
			},

			{
				"<leader>db",
				function()
					require("persistent-breakpoints.api").set_conditional_breakpoint()
				end,
				desc = "Conditional breakpoint",
			},
			{
				"<leader>dL",
				function()
					require("persistent-breakpoints.api").set_log_point()
				end,
				desc = "Log point",
			},
			{
				"<leader>dS",
				function()
					require("persistent-breakpoints.api").store_breakpoints()
				end,
				desc = "Save breakpoints",
			},
			{
				"<leader>dP",
				function()
					require("persistent-breakpoints.api").load_breakpoints()
				end,
				desc = "Load breakpoints",
			},
			{
				"<leader>dX",
				function()
					require("persistent-breakpoints.api").clear_all_breakpoints()
				end,
				desc = "Clear all breakpoints",
			},

			{
				"<leader>dj",
				function()
					require("dap").down()
				end,
				desc = "Down stack",
			},
			{
				"<leader>dk",
				function()
					require("dap").up()
				end,
				desc = "Up stack",
			},
			{
				"<leader>d.",
				function()
					require("dap").focus_frame()
				end,
				desc = "Focus frame",
			},
			{
				"<leader>dl",
				function()
					require("dap").run_last()
				end,
				desc = "Run last",
			},
			{
				"<leader>dr",
				function()
					require("dap").repl.toggle()
				end,
				desc = "REPL",
			},
			{
				"<leader>dt",
				function()
					require("dap").run_to_cursor()
				end,
				desc = "Run to cursor",
			},
			{
				"<leader>dq",
				function()
					require("dap").terminate()
				end,
				desc = "Terminate",
			},
			{
				"<leader>dR",
				function()
					require("dap").restart()
				end,
				desc = "Restart",
			},
			{
				"<leader>du",
				function()
					require("dapui").toggle()
				end,
				desc = "Toggle debug UI",
			},

			{
				"<leader>de",
				function()
					require("dap.ui.widgets").hover()
				end,
				mode = { "n", "v" },
				desc = "Hover evaluate",
			},

			{
				"<leader>dE",
				function()
					require("dap.ui.widgets").preview()
				end,
				mode = { "n", "v" },
				desc = "Preview evaluate",
			},

			{
				"<leader>ds",
				function()
					local widgets = require("dap.ui.widgets")
					widgets.centered_float(widgets.scopes)
				end,
				desc = "Scopes float",
			},

			{
				"<leader>d?",
				function()
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
				end,
				desc = "List breakpoints",
			},
		},
		config = function()
			require("mason").setup()

			require("mason-nvim-dap").setup({
				ensure_installed = { "codelldb" },
				automatic_installation = false,
			})

			local dap = require("dap")
			local dapui = require("dapui")

			require("nvim-dap-virtual-text").setup({
				commented = true,
				virt_text_pos = "eol",
			})

			local mason_root = path_join(vim.fn.stdpath("data"), "mason", "packages", "codelldb", "extension")

			local adapter = path_join(mason_root, "adapter", is_windows() and "codelldb.exe" or "codelldb")

			local adapter_command = adapter

			if not file_exists(adapter) then
				if executable_exists("codelldb") then
					adapter_command = "codelldb"
				else
					notify("CodeLLDB not found via Mason: " .. adapter, vim.log.levels.WARN)
				end
			end

			dap.adapters.codelldb = {
				type = "server",
				port = "${port}",
				executable = {
					command = adapter_command,
					args = { "--port", "${port}" },
				},
			}

			local launch_base = {
				type = "codelldb",
				request = "launch",
				program = ensure_executable,

				-- Important:
				-- Relative file paths are resolved next to the selected executable,
				-- not from the project root.
				cwd = executable_dir,

				args = current_args,
				env = current_env,
				runInTerminal = true,
				stopOnEntry = false,
			}

			dap.configurations.cpp = {
				vim.tbl_extend("force", {}, launch_base, {
					name = "Launch executable",
				}),

				vim.tbl_extend("force", {}, launch_base, {
					name = "Launch executable: stop on entry",
					stopOnEntry = true,
				}),

				vim.tbl_extend("force", {}, launch_base, {
					name = "Launch with Vulkan validation",
					env = validation_env,
				}),

				{
					name = "Attach process",
					type = "codelldb",
					request = "attach",
					pid = require("dap.utils").pick_process,
					cwd = executable_dir,
				},
			}

			dap.configurations.c = dap.configurations.cpp
			dap.configurations.rust = dap.configurations.cpp

			dapui.setup({
				layouts = {
					{
						elements = {
							{ id = "scopes", size = 0.45 },
							{ id = "stacks", size = 0.20 },
							{ id = "breakpoints", size = 0.15 },
							{ id = "watches", size = 0.20 },
						},
						size = 42,
						position = "left",
					},
					{
						elements = {
							{ id = "console", size = 0.60 },
							{ id = "repl", size = 0.40 },
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

			vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticError" })
			vim.fn.sign_define("DapBreakpointCondition", { text = "◆", texthl = "DiagnosticWarn" })
			vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DiagnosticWarn", linehl = "Visual" })
			vim.fn.sign_define("DapLogPoint", { text = "◉", texthl = "DiagnosticInfo" })
			vim.fn.sign_define("DapBreakpointRejected", { text = "○", texthl = "DiagnosticHint" })
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
}
