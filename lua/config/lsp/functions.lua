local f = {}

f.on_attach = function(client, bufnr)
	local opts = { noremap = true, silent = true, buffer = bufnr }

	--in file
	vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
	vim.keymap.set("n", "<leader>li", vim.lsp.buf.hover, opts)
	vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)

	--diagnostics
	vim.keymap.set("n", "]d", function()
		vim.diagnostic.jump({ count = 1, float = true })
	end, opts)

	vim.keymap.set("n", "[d", function()
		vim.diagnostic.jump({ count = -1, float = true })
	end, opts)

	vim.diagnostic.config({
		virtual_text = {
			spacing = 2,
			prefix = "",
			severity = { min = vim.diagnostic.severity.WARN },
			source = "if_many",
		},
		signs = true,
		underline = true,
		update_in_insert = false,
		severity_sort = true,
	})

	local function open_diagnostic_float()
		pcall(vim.diagnostic.open_float, nil, {
			focusable = false,
			border = "rounded",
			scope = "cursor",
		})
	end

	vim.keymap.set("n", "do", open_diagnostic_float, { desc = "diagnostics in float" })
end

f.capabilities = require("cmp_nvim_lsp").default_capabilities()
f.capabilities.textDocument.completion.completionItem.snippetSupport = true

return f
