local function project_root()
  local cwd = vim.fn.getcwd()
  local root = vim.fs.root(0, {
    ".git",
    "CMakeLists.txt",
    "compile_commands.json",
    "Makefile",
    "build.zig",
    "Cargo.toml",
  })
  return root or cwd
end

local function input_executable()
  local root = project_root()
  return vim.fn.input("Executable: ", root .. "/build/", "file")
end

local function input_args()
  local args = vim.fn.input("Args: ")
  if args == "" then
    return {}
  end
  return vim.split(args, " +", { trimempty = true })
end

local function build_project()
  local root = project_root()
  local jobs = tostring((vim.uv or vim.loop).available_parallelism() or 4)

  if vim.fn.filereadable(root .. "/CMakeLists.txt") == 1 then
    Snacks.terminal.open({ "cmake", "--build", "build", "-j", jobs }, {
      cwd = root,
      win = { position = "bottom", height = 0.30 },
    })
  elseif vim.fn.filereadable(root .. "/Makefile") == 1 then
    Snacks.terminal.open({ "make", "-j", jobs }, {
      cwd = root,
      win = { position = "bottom", height = 0.30 },
    })
  else
    Snacks.notify.warn("No CMakeLists.txt or Makefile found in project root")
  end
end

local function run_executable()
  local exe = input_executable()
  if exe == "" then
    return
  end
  Snacks.terminal.open(exe, {
    cwd = project_root(),
    win = { position = "bottom", height = 0.30 },
  })
end

return {
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    opts = {
      -- Large files should not destroy your editor.
      bigfile = { enabled = true },
      quickfile = { enabled = true },

      -- Main workflow pieces.
      dashboard = { enabled = true },
      explorer = {
        enabled = true,
        replace_netrw = false,
      },
      

      picker = {
        enabled = true,
        sources = {
          explorer = {
            layout = {
              layout = {
                position = "right",
              },
            },
          },
        },
      },
      terminal = { enabled = true },
      lazygit = { enabled = true },

      -- Editor quality-of-life.
      input = { enabled = true },
      notifier = { enabled = true, timeout = 3000 },
      indent = { enabled = false },
      scope = { enabled = false },
      scroll = { enabled = false },
      statuscolumn = { enabled = true },
      words = { enabled = false },
      toggle = { enabled = true },

      -- Lua/Neovim profiling. This is for profiling your editor/plugins/config,
      profiler = { enabled = false },
},
    keys = {
      -- Core files/search
      { "<leader>fs", function() Snacks.picker.smart() end, desc = "Smart files" },
      { "<leader>f,", function() Snacks.picker.buffers() end, desc = "Buffers" },
      { "<leader>f.", function() Snacks.picker.files() end, desc = "Find files" },
      { "<leader>f:", function() Snacks.picker.command_history() end, desc = "Command History" },
      { "<leader>fm", function() Snacks.picker.git_files() end, desc = "Git files" },
      { "<leader>fu", function() Snacks.picker.recent() end, desc = "Recent files" },
      { "<leader>fc", function() Snacks.picker.files({ cwd = vim.fn.stdpath("config") }) end, desc = "Find config" },
      { "<leader>/", function() Snacks.picker.grep() end, desc = "Grep" },
      { "<leader>sw", function() Snacks.picker.grep_word() end, mode = { "n", "x" }, desc = "Grep word/selection" },
      { "<leader>sd", function() Snacks.picker.diagnostics() end, desc = "Diagnostics" },
      { "<leader>sD", function() Snacks.picker.diagnostics_buffer() end, desc = "Buffer diagnostics" },
      { "<leader>sk", function() Snacks.picker.keymaps() end, desc = "Keymaps" },
      { "<leader>sh", function() Snacks.picker.help() end, desc = "Help" },
      { "<leader>sq", function() Snacks.picker.qflist() end, desc = "Quickfix" },
      { "<leader>sl", function() Snacks.picker.loclist() end, desc = "Location list" },
      { "<leader>fe", function() Snacks.explorer() end, desc = "File explorer" },
      { "<leader>fE", function() Snacks.explorer.reveal() end, desc = "Reveal current file in file explorer" },

      -- LSP through Snacks picker
      { "gd", function() Snacks.picker.lsp_definitions() end, desc = "Definition" },
      { "gD", function() Snacks.picker.lsp_declarations() end, desc = "Declaration" },
      { "gr", function() Snacks.picker.lsp_references() end, desc = "References" },
      { "gI", function() Snacks.picker.lsp_implementations() end, desc = "Implementation" },
      { "gy", function() Snacks.picker.lsp_type_definitions() end, desc = "Type definition" },
      { "<leader>ls", function() Snacks.picker.lsp_symbols() end, desc = "Document symbols" },
      { "<leader>lS", function() Snacks.picker.lsp_workspace_symbols() end, desc = "Workspace symbols" },

      -- Git
      { "<leader>gB", function() Snacks.picker.git_branches() end, desc = "Git branches" },
      { "<leader>gO", function() Snacks.gitbrowse() end, mode = { "n", "v" }, desc = "Open in browser" },

      -- Terminal/build/run
      { "<leader>ts", function() Snacks.terminal.toggle(nil, { win = { position = "bottom", height = 0.30 } }) end, desc = "Terminal" },
      { "<leader>tn", function() Snacks.terminal.open(nil, { cwd = project_root() }) end, desc = "New terminal" },

      -- Profiling your Neovim config/plugins
      { "<leader>ps", function() Snacks.profiler.scratch() end, desc = "Profiler scratch" },
      { "<leader>pn", function() Snacks.notifier.show_history() end, desc = "Notification history" },

      -- Scratch/utility
      { "<leader>.", function() Snacks.scratch() end, desc = "Scratch buffer" },
      { "<leader>S", function() Snacks.scratch.select() end, desc = "Select scratch" },
      { "<leader>bd", function() Snacks.bufdelete() end, desc = "Delete buffer" },
    },
    init = function()
      vim.api.nvim_create_autocmd("User", {
        pattern = "VeryLazy",
        callback = function()
          -- Better inspect/debug helpers for Lua config work.
          _G.dd = function(...)
            Snacks.debug.inspect(...)
          end
          _G.bt = function()
            Snacks.debug.backtrace()
          end
          vim.print = _G.dd

          -- Toggles
          Snacks.toggle.profiler():map("<leader>pp")
          Snacks.toggle.profiler_highlights():map("<leader>ph")
          Snacks.toggle.diagnostics():map("<leader>ud")
          Snacks.toggle.inlay_hints():map("<leader>uh")
          Snacks.toggle.treesitter():map("<leader>uT")
          Snacks.toggle.indent():map("<leader>ug")
          Snacks.toggle.option("wrap", { name = "Wrap" }):map("<leader>uw")
          Snacks.toggle.option("relativenumber", { name = "Relative number" }):map("<leader>uL")
        end,
      })
    end,
  },

  -- Optional but very useful: shows keymap groups while you learn the setup.
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      spec = {
        { "<leader>d", group = "debug" },
        { "<leader>f", group = "find" },
        { "<leader>g", group = "git" },
        { "<leader>p", group = "profile" },
        { "<leader>s", group = "search/symbols" },
        { "<leader>t", group = "terminal/build" },
        { "<leader>u", group = "ui toggles" },
      },
    },
  },

  -- DAP: actual debugging for C/C++/Rust executables.
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "williamboman/mason.nvim",
      "jay-babu/mason-nvim-dap.nvim",
      "rcarriga/nvim-dap-ui",
      "nvim-neotest/nvim-nio",
      "theHamsta/nvim-dap-virtual-text",
      "Weissle/persistent-breakpoints.nvim"
    },
    keys = {
      { "<F1>", function() require("dap").step_into() end, desc = "Step into" },
      { "<F2>", function() require("dap").step_over() end, desc = "Step over" },
      { "<F3>", function() require("dap").step_out() end, desc = "Step out" },
      { "<F4>", function() require("dapui").float_element("watches", { enter = true }) end, desc = "Watches" },
      { "<F5>", function() require("dap").continue() end, desc = "Continue/start" },
      { "<F8>", function() require("persistent-breakpoints.api").toggle_breakpoint() end, desc = "Toggle breakpoint" },
      { "<leader>db", function() require("persistent-breakpoints.api").set_conditional_breakpoint() end, desc = "Conditional breakpoint" },
      { "<leader>dL", function() require("persistent-breakpoints.api").set_log_point() end, desc = "Log point" },
      { "<leader>dX", function() require("persistent-breakpoints.api").clear_all_breakpoints() end, desc = "Clear all breakpoints" },
      { "<leader>dj", function() require("dap").down() end, desc = "Down stack" },
      { "<leader>dk", function() require("dap").up() end, desc = "Up stack" },
      { "<leader>d.", function() require("dap").focus_frame() end, desc = "Focus frame" },
      { "<leader>dl", function() require("dap").run_last() end, desc = "Run last" },
      { "<leader>dr", function() require("dap").repl.toggle() end, desc = "REPL" },
      { "<leader>dt", function() require("dap").run_to_cursor() end, desc = "Run to cursor" },
      { "<leader>dq", function() require("dap").terminate() end, desc = "Terminate" },
      { "<leader>dR", function() require("dap").restart() end, desc = "Restart" },
      { "<leader>du", function() require("dapui").toggle() end, desc = "Toggle debug UI" },

      { "<leader>d?", function()
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
      end, desc = "List breakpoints" }
    },
    config = function()
      require("mason").setup()
      require("mason-nvim-dap").setup({
        ensure_installed = { "codelldb" },
        automatic_installation = true,
        handlers = {
          function(config)
            require("mason-nvim-dap").default_setup(config)
          end,
        },
      })

      local dap = require("dap")
      local dapui = require("dapui")

      require("nvim-dap-virtual-text").setup({
        commented = true,
        virt_text_pos = "eol",
      })

      dapui.setup({
        layouts = {
          {
            elements = {
              { id = "scopes", size = 0.35 },
              { id = "breakpoints", size = 0.20 },
              { id = "stacks", size = 0.20 },
              { id = "watches", size = 0.25 },
            },
            size = 40,
            position = "left",
          },
          {
            elements = {
              { id = "repl", size = 0.50 },
              { id = "console", size = 0.50 },
            },
            size = 12,
            position = "bottom",
          },
        },
      })

      dap.listeners.before.attach.dapui_config = function()
        dapui.open()
      end
      dap.listeners.before.launch.dapui_config = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated.dapui_config = function()
        dapui.close()
      end
      dap.listeners.before.event_exited.dapui_config = function()
        dapui.close()
      end

      -- Signs
      vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticError" })
      vim.fn.sign_define("DapBreakpointCondition", { text = "◆", texthl = "DiagnosticWarn" })
      vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DiagnosticInfo", linehl = "Visual" })
      vim.fn.sign_define("DapLogPoint", { text = "◆", texthl = "DiagnosticInfo" })
      vim.fn.sign_define("DapBreakpointRejected", { text = "○", texthl = "DiagnosticHint" })

      -- C/C++/Rust config via codelldb.
      -- Build with debug symbols, e.g.:
      --   cmake -S . -B build -DCMAKE_BUILD_TYPE=Debug
      --   cmake --build build
      local native_launch = {
        name = "Launch executable",
        type = "codelldb",
        request = "launch",
        program = input_executable,
        cwd = function()
          return project_root()
        end,
        stopOnEntry = false,
        args = input_args,
        console = "integratedTerminal",
      }

      local native_launch_stop = vim.tbl_deep_extend("force", native_launch, {
        name = "Launch executable: stop on entry",
        stopOnEntry = true,
      })

      dap.configurations.cpp = { native_launch, native_launch_stop }
      dap.configurations.c = dap.configurations.cpp
      dap.configurations.rust = dap.configurations.cpp
    end,
  },
}
