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

			local function normalize_path(p)
				if not p or p == "" then
					return p
				end
				return vim.fn.fnamemodify(p, ":p")
			end

			local function file_exists(p)
				return p and uv.fs_stat(p) ~= nil
			end

			local function is_dir(p)
				local st = p and uv.fs_stat(p)
				return st and st.type == "directory"
			end

			local function read_text_file(p)
				local ok, lines = pcall(vim.fn.readfile, p)
				if not ok or not lines then
					return nil
				end
				return table.concat(lines, "\n")
			end

			local function read_json_file(p)
				local text = read_text_file(p)
				if not text then
					return nil
				end
				local ok, obj = pcall(vim.json.decode, text)
				if not ok then
					return nil
				end
				return obj
			end

			local function notify(msg, level)
				vim.notify(msg, level or vim.log.levels.INFO, { title = "DAP" })
			end

			local function workspace_root()
				return normalize_path(vim.fn.getcwd())
			end

			local function workspace_key()
				return workspace_root()
			end

			-- -------------------------
			-- Persistent-ish in-memory workspace state
			-- -------------------------
			local state = {
				by_ws = {},
			}

			local function ws_state()
				local key = workspace_key()
				state.by_ws[key] = state.by_ws[key]
					or {
						last_executable = nil,
						last_build_dir = nil,
						last_cwd = nil,
						last_target = nil,
						last_test_target = nil,
						last_args = {},
						last_env = vim.empty_dict(),
					}
				return state.by_ws[key]
			end

			local function set_state_field(k, v)
				ws_state()[k] = v
			end

			local function get_state_field(k)
				return ws_state()[k]
			end

			-- -------------------------
			-- Path/template helpers
			-- -------------------------
			local function expand_preset_path(s, source_dir)
				if type(s) ~= "string" then
					return nil
				end
				s = s:gsub("%${sourceDir}", source_dir)
				s = s:gsub("%${workspaceFolder}", source_dir)
				s = s:gsub("%${sourceParentDir}", vim.fn.fnamemodify(source_dir, ":h"))
				s = s:gsub("%${sourceDirName}", vim.fn.fnamemodify(source_dir, ":t"))
				return normalize_path(s)
			end

			-- -------------------------
			-- Executable detection
			-- -------------------------
			local function is_probably_executable(p)
				if not p or p == "" then
					return false
				end

				if p:match("[/\\]CMakeFiles[/\\]") then
					return false
				end

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
					local m = st.mode
					local owner_exec = math.floor(m / 64) % 2 == 1
					local group_exec = math.floor(m / 8) % 2 == 1
					local other_exec = m % 2 == 1
					return owner_exec or group_exec or other_exec
				end

				return false
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
						table.insert(filtered, normalize_path(p))
					end
				end

				table.sort(filtered)
				return filtered
			end

			-- -------------------------
			-- Simple selection helper
			-- -------------------------
			local function select_sync(items, opts, fallback)
				local choice = nil
				vim.ui.select(items, opts or {}, function(item)
					choice = item
				end)

				vim.wait(2500, function()
					return choice ~= nil
				end, 25)

				if choice ~= nil then
					return choice
				end

				if fallback ~= nil then
					return fallback
				end

				return items and items[1] or nil
			end

			-- -------------------------
			-- Prompt helpers
			-- -------------------------
			local function pick_args(default_args)
				local initial = ""
				if type(default_args) == "table" and #default_args > 0 then
					initial = table.concat(default_args, " ")
				end

				local s = vim.fn.input("Args: ", initial)
				if not s or vim.trim(s) == "" then
					set_state_field("last_args", {})
					return {}
				end

				local args = vim.fn.split(s, " ", true)
				set_state_field("last_args", args)
				return args
			end

			local function pick_env(default_env)
				local default_str = ""
				if type(default_env) == "table" then
					local parts = {}
					for k, v in pairs(default_env) do
						table.insert(parts, tostring(k) .. "=" .. tostring(v))
					end
					table.sort(parts)
					default_str = table.concat(parts, ",")
				end

				local s = vim.fn.input("Env (KEY=VAL, comma-separated): ", default_str)
				if not s or vim.trim(s) == "" then
					local env = vim.empty_dict()
					set_state_field("last_env", env)
					return env
				end

				local env = vim.empty_dict()
				for kv in s:gmatch("[^,]+") do
					local k, v = kv:match("^%s*([^=]+)%s*=%s*(.-)%s*$")
					if k and v then
						env[k] = v
					end
				end

				set_state_field("last_env", env)
				return env
			end

			-- -------------------------
			-- Working directory selection
			-- -------------------------
			local function pick_cwd(default_exe)
				local ws = workspace_root()
				local exe_dir = default_exe and vim.fn.fnamemodify(default_exe, ":p:h") or ws
				local build_dir = get_state_field("last_build_dir") or ws
				local last_cwd = get_state_field("last_cwd")

				local entries = {
					{ label = "Workspace root", value = ws },
					{ label = "Executable dir", value = exe_dir },
					{ label = "Build dir", value = build_dir },
				}

				if last_cwd and last_cwd ~= ws and last_cwd ~= exe_dir and last_cwd ~= build_dir then
					table.insert(entries, 1, { label = "Last CWD", value = last_cwd })
				end

				table.insert(entries, { label = "Custom...", value = "__custom__" })

				local labels = {}
				for _, e in ipairs(entries) do
					table.insert(labels, e.label .. "  ->  " .. e.value)
				end

				local chosen = select_sync(labels, { prompt = "Select working directory:" }, labels[1])
				local picked_index = 1
				for i, label in ipairs(labels) do
					if label == chosen then
						picked_index = i
						break
					end
				end

				local value = entries[picked_index].value
				if value == "__custom__" then
					value = vim.fn.input("CWD: ", last_cwd or ws, "dir")
				end

				value = normalize_path(value)
				set_state_field("last_cwd", value)
				return value
			end

			local function cwd_from_last_or_pick()
				local cwd = get_state_field("last_cwd")
				if cwd and is_dir(cwd) then
					return cwd
				end
				return pick_cwd(get_state_field("last_executable"))
			end

			-- -------------------------
			-- CMake build directory discovery
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

				for _, d in ipairs(vim.fn.glob(path_join(source_dir, "out", "build", "*"), 1, 1)) do
					table.insert(dirs, d)
				end

				for _, d in ipairs(vim.fn.glob(path_join(source_dir, "cmake-build-*"), 1, 1)) do
					table.insert(dirs, d)
				end

				local seen, uniq = {}, {}
				for _, d in ipairs(dirs) do
					d = normalize_path(d)
					if d and d ~= "" and not seen[d] then
						seen[d] = true
						table.insert(uniq, d)
					end
				end

				return uniq
			end

			local function find_existing_build_dirs(source_dir)
				local out = {}
				for _, d in ipairs(get_candidate_build_dirs(source_dir)) do
					if is_dir(d) then
						table.insert(out, d)
					end
				end
				return out
			end

			local function pick_build_dir()
				local last = get_state_field("last_build_dir")
				if last and is_dir(last) then
					return last
				end

				local dirs = find_existing_build_dirs(workspace_root())
				if #dirs == 0 then
					local manual = vim.fn.input("Build directory: ", path_join(workspace_root(), "build"), "dir")
					manual = normalize_path(manual)
					set_state_field("last_build_dir", manual)
					return manual
				end

				if #dirs == 1 then
					set_state_field("last_build_dir", dirs[1])
					return dirs[1]
				end

				local chosen = select_sync(dirs, { prompt = "Select build directory:" }, dirs[1])
				set_state_field("last_build_dir", chosen)
				return chosen
			end

			-- -------------------------
			-- CMake File API
			-- -------------------------
			local function ensure_cmake_file_api_query(build_dir)
				local query_dir = path_join(build_dir, ".cmake", "api", "v1", "query")
				vim.fn.mkdir(query_dir, "p")

				local query_files = {
					path_join(query_dir, "codemodel-v2"),
					path_join(query_dir, "cache-v2"),
				}

				for _, q in ipairs(query_files) do
					if not file_exists(q) then
						vim.fn.writefile({ "" }, q)
					end
				end
			end

			local function find_latest_reply_index(build_dir)
				local reply_dir = path_join(build_dir, ".cmake", "api", "v1", "reply")
				if not is_dir(reply_dir) then
					return nil
				end

				local files = vim.fn.glob(path_join(reply_dir, "index-*.json"), 1, 1)
				if not files or #files == 0 then
					return nil
				end

				table.sort(files)
				return files[#files]
			end

			local function cmake_configure_if_needed(build_dir)
				ensure_cmake_file_api_query(build_dir)

				local index = find_latest_reply_index(build_dir)
				if index then
					return true
				end

				local source_dir = workspace_root()
				local cmd = { "cmake", "-S", source_dir, "-B", build_dir }
				notify("Running configure for CMake File API: " .. table.concat(cmd, " "))

				local result = vim.system(cmd, { text = true }):wait()
				if result.code ~= 0 then
					local output = (result.stderr and result.stderr ~= "" and result.stderr) or result.stdout or ""
					notify("CMake configure failed\n" .. output, vim.log.levels.ERROR)
					return false
				end

				return true
			end

			local function parse_cmake_targets(build_dir)
				if not cmake_configure_if_needed(build_dir) then
					return {}
				end

				local index_path = find_latest_reply_index(build_dir)
				if not index_path then
					return {}
				end

				local index = read_json_file(index_path)
				if not index or not index.reply then
					return {}
				end

				local codemodel_reply = index.reply["codemodel-v2"]
				if not codemodel_reply or not codemodel_reply.jsonFile then
					return {}
				end

				local reply_dir = path_join(build_dir, ".cmake", "api", "v1", "reply")
				local codemodel = read_json_file(path_join(reply_dir, codemodel_reply.jsonFile))
				if not codemodel or type(codemodel.configurations) ~= "table" then
					return {}
				end

				local targets = {}

				for _, cfg in ipairs(codemodel.configurations) do
					if type(cfg.targets) == "table" then
						for _, t in ipairs(cfg.targets) do
							if t.jsonFile then
								local tjson = read_json_file(path_join(reply_dir, t.jsonFile))
								if tjson then
									local kind = tjson.type or t.type or "UNKNOWN"
									local name = tjson.name or t.name
									local artifacts = {}

									if type(tjson.artifacts) == "table" then
										for _, a in ipairs(tjson.artifacts) do
											if a.path then
												table.insert(artifacts, normalize_path(path_join(build_dir, a.path)))
											end
										end
									end

									local executable = nil
									for _, a in ipairs(artifacts) do
										if is_probably_executable(a) then
											executable = a
											break
										end
									end

									targets[name] = {
										name = name,
										type = kind,
										executable = executable,
										artifacts = artifacts,
										raw = tjson,
									}
								end
							end
						end
					end
				end

				return targets
			end

			local function get_cmake_targets()
				local build_dir = pick_build_dir()
				return parse_cmake_targets(build_dir), build_dir
			end

			local function list_target_names(targets, filter_fn)
				local names = {}
				for name, info in pairs(targets) do
					if not filter_fn or filter_fn(info) then
						table.insert(names, name)
					end
				end
				table.sort(names)
				return names
			end

			local function is_test_target_name(name)
				local l = name:lower()
				return l:match("test") ~= nil or l:match("tests") ~= nil or l:match("unittest") ~= nil
			end

			local function is_executable_target(info)
				return info and info.type == "EXECUTABLE"
			end

			local function is_test_target(info)
				return is_executable_target(info) and info.name and is_test_target_name(info.name)
			end

			local function pick_cmake_target(opts)
				opts = opts or {}
				local targets, build_dir = get_cmake_targets()

				local names = list_target_names(targets, opts.filter)
				if #names == 0 then
					local manual = vim.fn.input("CMake target: ", get_state_field("last_target") or "")
					manual = vim.trim(manual or "")
					set_state_field("last_target", manual)
					return manual, nil, build_dir
				end

				local preferred = opts.default_name
				if preferred and targets[preferred] then
					set_state_field("last_target", preferred)
					return preferred, targets[preferred], build_dir
				end

				local labels = {}
				for _, name in ipairs(names) do
					local info = targets[name]
					local suffix = ""
					if info.executable then
						suffix = " -> " .. info.executable
					end
					table.insert(labels, string.format("%s [%s]%s", name, info.type or "?", suffix))
				end

				local chosen = select_sync(labels, {
					prompt = opts.prompt or "Select CMake target:",
				}, labels[1])

				local chosen_name = nil
				for i, label in ipairs(labels) do
					if label == chosen then
						chosen_name = names[i]
						break
					end
				end

				chosen_name = chosen_name or names[1]
				set_state_field("last_target", chosen_name)
				return chosen_name, targets[chosen_name], build_dir
			end

			local function pick_test_target()
				local default_name = get_state_field("last_test_target")
				local name, info, build_dir = pick_cmake_target({
					prompt = "Select test target:",
					default_name = default_name,
					filter = is_test_target,
				})
				if name and name ~= "" then
					set_state_field("last_test_target", name)
					set_state_field("last_target", name)
				end
				return name, info, build_dir
			end

			-- -------------------------
			-- Build helpers
			-- -------------------------
			local function build_cmake_target(opts)
				opts = opts or {}

				local build_dir = opts.build_dir or pick_build_dir()
				if not build_dir or build_dir == "" then
					notify("No build directory selected", vim.log.levels.ERROR)
					return false
				end

				set_state_field("last_build_dir", build_dir)

				local target = opts.target
				if target == nil then
					target = vim.fn.input("CMake target (empty = default/all): ", get_state_field("last_target") or "")
					target = vim.trim(target or "")
				end

				if target and target ~= "" then
					set_state_field("last_target", target)
				end

				local cmd = { "cmake", "--build", build_dir, "--config", "Debug" }
				if target and target ~= "" then
					vim.list_extend(cmd, { "--target", target })
				end

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

			local function resolve_executable_for_target(target_name)
				if not target_name or target_name == "" then
					return nil
				end

				local targets = parse_cmake_targets(pick_build_dir())
				local info = targets[target_name]
				if info and info.executable and file_exists(info.executable) then
					set_state_field("last_executable", info.executable)
					return info.executable
				end

				return nil
			end

			local function pick_cmake_executable()
				local last = get_state_field("last_executable")
				if last and file_exists(last) then
					return last
				end

				local target = get_state_field("last_target")
				if target and target ~= "" then
					local exe = resolve_executable_for_target(target)
					if exe then
						return exe
					end
				end

				local build_dir = pick_build_dir()
				local candidates = find_exes_in_dir(build_dir)

				if #candidates == 0 then
					local manual = vim.fn.input("Path to executable: ", workspace_root() .. "/", "file")
					manual = normalize_path(manual)
					if manual and manual ~= "" then
						set_state_field("last_executable", manual)
					end
					return manual
				end

				local chosen = select_sync(candidates, { prompt = "Select executable to debug:" }, candidates[1])
				set_state_field("last_executable", chosen)
				return chosen
			end

			local function build_and_resolve_target_executable()
				local target_name, target_info, build_dir = pick_cmake_target({
					prompt = "Build + debug target:",
					filter = is_executable_target,
				})

				if not target_name or target_name == "" then
					error("No target selected")
				end

				local ok = build_cmake_target({
					build_dir = build_dir,
					target = target_name,
				})
				if not ok then
					error("Build failed")
				end

				local targets = parse_cmake_targets(build_dir)
				local info = targets[target_name] or target_info
				local exe = info and info.executable or nil

				if not exe or not file_exists(exe) then
					exe = pick_cmake_executable()
				end

				if exe and exe ~= "" then
					set_state_field("last_executable", exe)
				end

				return exe
			end

			local function build_and_resolve_test_executable()
				local target_name, target_info, build_dir = pick_test_target()

				if not target_name or target_name == "" then
					error("No test target selected")
				end

				local ok = build_cmake_target({
					build_dir = build_dir,
					target = target_name,
				})
				if not ok then
					error("Build failed")
				end

				local targets = parse_cmake_targets(build_dir)
				local info = targets[target_name] or target_info
				local exe = info and info.executable or nil

				if not exe or not file_exists(exe) then
					exe = pick_cmake_executable()
				end

				if exe and exe ~= "" then
					set_state_field("last_executable", exe)
				end

				return exe
			end

			local function build_last_target_and_resolve()
				local target = get_state_field("last_target")
				if not target or target == "" then
					return build_and_resolve_target_executable()
				end

				local build_dir = pick_build_dir()
				local ok = build_cmake_target({
					build_dir = build_dir,
					target = target,
				})
				if not ok then
					error("Build failed")
				end

				local exe = resolve_executable_for_target(target)
				if exe then
					return exe
				end

				return pick_cmake_executable()
			end

			-- -------------------------
			-- Vulkan / RenderDoc helpers
			-- -------------------------
			local function merge_env(a, b)
				local out = vim.empty_dict()

				if type(a) == "table" then
					for k, v in pairs(a) do
						out[k] = v
					end
				end
				if type(b) == "table" then
					for k, v in pairs(b) do
						out[k] = v
					end
				end

				return out
			end

			local function vulkan_validation_env()
				return vim.tbl_extend("force", vim.empty_dict(), {
					VK_LAYER_PATH = os.getenv("VK_LAYER_PATH") or "",
					VK_INSTANCE_LAYERS = "VK_LAYER_KHRONOS_validation",
				})
			end

			local function build_last_target_with_validation()
				return build_last_target_and_resolve()
			end

			local function renderdoc_capture_and_return_exe()
				local exe = build_last_target_and_resolve()
				if not exe or exe == "" then
					error("No executable found for RenderDoc capture")
				end

				local args = get_state_field("last_args") or {}
				local cwd = get_state_field("last_cwd") or workspace_root()

				local cmd = { "renderdoccmd", "capture", exe }
				for _, arg in ipairs(args) do
					table.insert(cmd, arg)
				end

				notify("Starting RenderDoc capture: " .. table.concat(cmd, " "))
				local result = vim.system(cmd, {
					cwd = cwd,
					text = true,
				}):wait()

				if result.code ~= 0 then
					local output = (result.stderr and result.stderr ~= "" and result.stderr) or result.stdout or ""
					notify("RenderDoc capture failed\n" .. output, vim.log.levels.ERROR)
				else
					notify("RenderDoc capture finished")
				end

				return exe
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
			-- DAP configurations
			-- -------------------------
			dap.configurations.cpp = {
				{
					name = "Build + Launch (choose CMake target)",
					type = "codelldb",
					request = "launch",
					program = build_and_resolve_target_executable,
					cwd = function()
						return pick_cwd(get_state_field("last_executable"))
					end,
					stopOnEntry = false,
					args = function()
						return get_state_field("last_args") or {}
					end,
					env = function()
						return get_state_field("last_env") or vim.empty_dict()
					end,
					runInTerminal = true,
				},
				{
					name = "Build + Launch (last target)",
					type = "codelldb",
					request = "launch",
					program = build_last_target_and_resolve,
					cwd = cwd_from_last_or_pick,
					stopOnEntry = false,
					args = function()
						return get_state_field("last_args") or {}
					end,
					env = function()
						return get_state_field("last_env") or vim.empty_dict()
					end,
					runInTerminal = true,
				},
				{
					name = "Build + Launch Test",
					type = "codelldb",
					request = "launch",
					program = build_and_resolve_test_executable,
					cwd = function()
						return pick_cwd(get_state_field("last_executable"))
					end,
					stopOnEntry = false,
					args = function()
						local last = get_state_field("last_args") or {}
						return pick_args(last)
					end,
					env = function()
						return get_state_field("last_env") or vim.empty_dict()
					end,
					runInTerminal = true,
				},
				{
					name = "Launch (ask executable)",
					type = "codelldb",
					request = "launch",
					program = function()
						local p = vim.fn.input("Path to executable: ", workspace_root() .. "/", "file")
						p = normalize_path(p)
						if p ~= "" then
							set_state_field("last_executable", p)
						end
						return p
					end,
					cwd = function()
						return pick_cwd(get_state_field("last_executable"))
					end,
					stopOnEntry = false,
					args = function()
						return pick_args(get_state_field("last_args"))
					end,
					env = function()
						return pick_env(get_state_field("last_env"))
					end,
					runInTerminal = true,
				},
				{
					name = "Launch (manual args/env)",
					type = "codelldb",
					request = "launch",
					program = function()
						local exe = pick_cmake_executable()
						set_state_field("last_executable", exe)
						return exe
					end,
					cwd = function()
						return pick_cwd(get_state_field("last_executable"))
					end,
					stopOnEntry = false,
					args = function()
						return pick_args(get_state_field("last_args"))
					end,
					env = function()
						return pick_env(get_state_field("last_env"))
					end,
					runInTerminal = true,
				},
				{
					name = "Launch (Vulkan validation)",
					type = "codelldb",
					request = "launch",
					program = build_last_target_with_validation,
					cwd = cwd_from_last_or_pick,
					stopOnEntry = false,
					args = function()
						return get_state_field("last_args") or {}
					end,
					env = function()
						return merge_env(get_state_field("last_env"), vulkan_validation_env())
					end,
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
			map("n", "<leader>ds", dap.run_last, { desc = "DAP: Run Last" })
			map("n", "<leader>dt", dap.terminate, { desc = "DAP: Terminate" })

			-- Build / targets
			map("n", "<leader>dB", function()
				build_cmake_target({})
			end, { desc = "DAP: Build CMake target" })

			map("n", "<leader>dT", function()
				local name = select(
					1,
					pick_cmake_target({
						prompt = "Select main target:",
						filter = is_executable_target,
					})
				)
				if name and name ~= "" then
					notify("Selected target: " .. name)
				end
			end, { desc = "DAP: Pick target" })

			map("n", "<leader>dX", function()
				local name = select(1, pick_test_target())
				if name and name ~= "" then
					notify("Selected test target: " .. name)
				end
			end, { desc = "DAP: Pick test target" })

			map("n", "<leader>dc", function()
				local cwd = pick_cwd(get_state_field("last_executable"))
				if cwd and cwd ~= "" then
					notify("CWD set to: " .. cwd)
				end
			end, { desc = "DAP: Pick CWD" })

			map("n", "<leader>da", function()
				pick_args(get_state_field("last_args"))
			end, { desc = "DAP: Pick args" })

			map("n", "<leader>dE", function()
				pick_env(get_state_field("last_env"))
			end, { desc = "DAP: Pick env" })

			map("n", "<leader>dvk", function()
				local env = merge_env(get_state_field("last_env"), vulkan_validation_env())
				set_state_field("last_env", env)
				notify("Vulkan validation env prepared")
			end, { desc = "DAP: Prepare Vulkan validation env" })

			map("n", "<leader>dR", function()
				renderdoc_capture_and_return_exe()
			end, { desc = "DAP: RenderDoc capture" })

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
		end,
	},

	-- ------------------------------------------------------------
	-- DAP UI
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
			map(
				"n",
				"<leader>dpt",
				"<cmd>Telescope dap list_breakpoints<CR>",
				{ desc = "DAP: Breakpoints (Telescope)" }
			)
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
