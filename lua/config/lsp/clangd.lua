local M = {}

local clangd_cmd = {
	"clangd",
	"--background-index",
	"--clang-tidy",
	"--completion-style=detailed",
	"--header-insertion=never",
	"--suggest-missing-includes",
	"--all-scopes-completion",
	"--header-insertion-decorators=0",
}

function M.setup(on_attach, capabilities)
	capabilities.textDocument.completion.completionItem.snippetSupport = false

	vim.lsp.config("clangd", {
		cmd = clangd_cmd,
		on_attach = function(client, bufnr)
			client.server_capabilities.diagnosticProvider = false
			vim.diagnostic.enable(false, { bufnr = bufnr })

			on_attach(client, bufnr)
		end,
		capabilities = capabilities,
	})

	vim.lsp.enable("clangd")
end

return M
