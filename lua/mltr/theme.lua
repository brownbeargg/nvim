local M = {}

local colors = {
	-- Base
	bg = "#14161A",
	fg = "#D4D7DD",

	gutter = "#191D23",
	border = "#2A313A",
	dim = "#7F8894",

	-- Syntax
	comment = "#66707A",
	string = "#93B78E",

	-- Language roles
	keyword = "#C89156", -- if, for, return
	qualifier = "#a79f91", -- const, static, constexpr
	decl = "#6EA8B0", -- class, struct, enum, template
	kw_operator = "#C97E5F", -- new, delete, sizeof, decltype

	func = "#D89A62",
	ident = "#afa178",
	type = "#8FD0DA",
	constant = "#C26D6D",
	number = "#B8C98E",
	param = "#D9C08F",

	-- UI
	visual = "#24303A",
	error = "#D56B6B",

	-- Details
	cursor = "#1C2128",
	lineNr = "#5F6873",
	split = "#2A313A",
	eob = "#1A1E24",

	info = "#7CB4D8",
	hint = "#88BFAE",
	warn = "#C8A86A",
}

local function hl(name, opts)
	vim.api.nvim_set_hl(0, name, opts)
end

local function link(from, to)
	hl(from, { link = to })
end

local function setTransparent(transparent)
	if not transparent then
		return
	end

	vim.cmd([[
    highlight Normal guibg=NONE ctermbg=NONE
    highlight NormalNC guibg=NONE ctermbg=NONE
    highlight EndOfBuffer guibg=NONE ctermbg=NONE
    highlight SignColumn guibg=NONE ctermbg=NONE
    highlight VertSplit guibg=NONE ctermbg=NONE
  ]])
end

local function setBasicColors(transparent)
	local bg = transparent and "NONE" or colors.bg

	hl("Normal", { fg = colors.fg, bg = bg })
	hl("NormalNC", { fg = colors.fg, bg = bg })
	hl("CursorLine", { bg = colors.cursor })
	hl("Visual", { bg = colors.visual })
	hl("LineNr", { fg = colors.lineNr })
	hl("CursorLineNr", { fg = colors.fg })
	hl("VertSplit", { fg = colors.split, bg = bg })
	hl("SignColumn", { bg = bg })
	hl("EndOfBuffer", { fg = colors.eob })
	hl("ColorColumn", { bg = colors.cursor })
	hl("CursorColumn", { bg = colors.cursor })
	hl("MatchParen", { fg = colors.type, bg = colors.cursor })
	hl("Search", { fg = colors.bg, bg = colors.type })
	hl("IncSearch", { fg = colors.bg, bg = colors.func })
	hl("Substitute", { fg = colors.bg, bg = colors.keyword })
end

local function setCoreSyntax()
	-- Classic syntax groups
	hl("Comment", { fg = colors.comment })
	hl("String", { fg = colors.string })
	hl("Character", { fg = colors.string })
	hl("Number", { fg = colors.number })
	hl("Boolean", { fg = colors.constant })
	hl("Constant", { fg = colors.constant })

	hl("Identifier", { fg = colors.ident })
	hl("Function", { fg = colors.func, bold = true })

	hl("Statement", { fg = colors.keyword })
	hl("Keyword", { fg = colors.keyword })
	hl("Operator", { fg = colors.dim })

	hl("StorageClass", { fg = colors.qualifier })
	hl("Structure", { fg = colors.decl })
	hl("Typedef", { fg = colors.decl })

	hl("Type", { fg = colors.type })
	hl("Special", { fg = colors.constant })
	hl("SpecialChar", { fg = colors.constant })
	hl("PreProc", { fg = colors.decl })
	hl("Include", { fg = colors.decl })
	hl("Define", { fg = colors.qualifier, bold = true })
	hl("Macro", { fg = colors.decl, bold = true })

	hl("Error", { fg = colors.error })
	hl("ErrorMsg", { fg = colors.error })
	hl("WarningMsg", { fg = colors.warn })

	hl("DiagnosticError", { fg = colors.error })
	hl("DiagnosticWarn", { fg = colors.warn })
	hl("DiagnosticInfo", { fg = colors.info })
	hl("DiagnosticHint", { fg = colors.hint })

	hl("DiagnosticVirtualTextError", { fg = colors.error, bg = "NONE" })
	hl("DiagnosticVirtualTextWarn", { fg = colors.warn, bg = "NONE" })
	hl("DiagnosticVirtualTextInfo", { fg = colors.info, bg = "NONE" })
	hl("DiagnosticVirtualTextHint", { fg = colors.hint, bg = "NONE" })

	hl("DiagnosticUnderlineError", { undercurl = true, sp = colors.error })
	hl("DiagnosticUnderlineWarn", { undercurl = true, sp = colors.warn })
	hl("DiagnosticUnderlineInfo", { undercurl = true, sp = colors.info })
	hl("DiagnosticUnderlineHint", { undercurl = true, sp = colors.hint })

	hl("Delimiter", { fg = colors.dim })
end

local function setTreesitterAndLsp()
	-- Treesitter basics
	link("@comment", "Comment")
	link("@string", "String")
	link("@string.escape", "SpecialChar")
	link("@character", "Character")
	link("@number", "Number")
	link("@boolean", "Boolean")
	link("@constant", "Constant")
	link("@constant.builtin", "Constant")

	-- Functions / methods
	link("@function", "Function")
	link("@function.builtin", "Function")
	link("@function.call", "Function")
	link("@function.method", "Function")
	link("@function.method.call", "Function")
	link("@method", "Function")
	link("@method.call", "Function")

	link("@operator", "Operator")

	-- Variables / identifiers
	link("@variable", "Identifier")
	link("@identifier", "Identifier")
	hl("@variable.builtin", { fg = colors.qualifier })
	hl("@property", { fg = colors.ident })
	hl("@field", { fg = colors.ident })

	-- Parameters
	hl("Parameter", { fg = colors.param, italic = true })
	link("@parameter", "Parameter")
	link("@variable.parameter", "Parameter")

	-- Types
	hl("@type", { fg = colors.type })
	hl("@type.builtin", { fg = colors.type })
	hl("@type.definition", { fg = colors.decl })
	hl("@type.qualifier", { fg = colors.qualifier })

	-- Declaration keywords
	hl("@keyword", { fg = colors.keyword })
	hl("@keyword.conditional", { fg = colors.keyword })
	hl("@keyword.repeat", { fg = colors.keyword })
	hl("@keyword.return", { fg = colors.keyword })
	hl("@keyword.exception", { fg = colors.keyword })

	hl("@keyword.type", { fg = colors.decl })
	hl("@keyword.import", { fg = colors.decl })
	hl("@keyword.directive", { fg = colors.decl, bold = true })
	hl("@keyword.directive.define", { fg = colors.qualifier, bold = true })

	hl("@keyword.modifier", { fg = colors.qualifier, bold = true })
	hl("@keyword.operator", { fg = colors.kw_operator, italic = true })

	-- Constructors / namespaces
	hl("@constructor", { fg = colors.func })
	hl("@module", { fg = colors.decl })
	hl("@namespace", { fg = colors.decl })

	-- Punctuation
	hl("@punctuation", { fg = colors.dim })
	hl("@punctuation.delimiter", { fg = colors.dim })
	hl("@punctuation.bracket", { fg = colors.fg })
	hl("@punctuation.special", { fg = colors.keyword })

	-- Rainbow delimiters
	hl("RainbowDelimiterYellow", { fg = colors.keyword })
	hl("RainbowDelimiterOrange", { fg = colors.func })
	hl("RainbowDelimiterCyan", { fg = colors.type })
	hl("RainbowDelimiterBlue", { fg = colors.info })
	hl("RainbowDelimiterViolet", { fg = colors.param })

	-- LSP semantic tokens
	hl("@lsp.type.keyword", { fg = colors.keyword })
	hl("@lsp.type.operator", { fg = colors.kw_operator, italic = true })

	hl("@lsp.type.type", { fg = colors.type })
	hl("@lsp.type.class", { fg = colors.type })
	hl("@lsp.type.struct", { fg = colors.type })
	hl("@lsp.type.enum", { fg = colors.type })
	hl("@lsp.type.interface", { fg = colors.type })
	hl("@lsp.type.namespace", { fg = colors.decl })
	hl("@lsp.type.typeParameter", { fg = colors.param })

	hl("@lsp.type.variable", { fg = colors.ident })
	hl("@lsp.type.property", { fg = colors.ident })
	hl("@lsp.type.parameter", { fg = colors.param, italic = true })

	hl("@lsp.type.function", { fg = colors.func, bold = true })
	hl("@lsp.type.method", { fg = colors.func, bold = true })

	-- Cruciaal: typemods overrulen vaak gewone lsp.type groepen
	hl("@lsp.typemod.function.declaration", { fg = colors.func, bold = true })
	hl("@lsp.typemod.function.definition", { fg = colors.func, bold = true })
	hl("@lsp.typemod.function.defaultLibrary", { fg = colors.func, bold = true })

	hl("@lsp.typemod.method.declaration", { fg = colors.func, bold = true })
	hl("@lsp.typemod.method.definition", { fg = colors.func, bold = true })
	hl("@lsp.typemod.method.defaultLibrary", { fg = colors.func, bold = true })

	hl("@lsp.typemod.variable.readonly", { fg = colors.qualifier })
	hl("@lsp.typemod.property.readonly", { fg = colors.qualifier })
	hl("@lsp.mod.defaultLibrary", { fg = colors.qualifier })
	hl("@lsp.mod.readonly", { fg = colors.qualifier })
end

local function setStatusAndTabs(transparent)
	local bg = transparent and "NONE" or colors.gutter
	local mainbg = transparent and "NONE" or colors.bg

	hl("StatusLine", { fg = colors.fg, bg = bg })
	hl("StatusLineNC", { fg = colors.dim, bg = bg })
	hl("WinSeparator", { fg = colors.border, bg = mainbg })

	hl("TabLine", { fg = colors.dim, bg = bg })
	hl("TabLineSel", { fg = colors.fg, bg = mainbg })
	hl("TabLineFill", { bg = bg })
end

local function setFloatAndPopup(transparent)
	local bg = transparent and "NONE" or colors.gutter

	hl("NormalFloat", { fg = colors.fg, bg = bg })
	hl("FloatBorder", { fg = colors.border, bg = bg })
	hl("FloatTitle", { fg = colors.type, bg = bg })

	hl("Pmenu", { fg = colors.fg, bg = bg })
	hl("PmenuSel", { fg = colors.fg, bg = colors.cursor })
	hl("PmenuSbar", { bg = bg })
	hl("PmenuThumb", { bg = colors.border })

	hl("WildMenu", { fg = colors.fg, bg = colors.cursor })

	-- nvim-cmp convenience links
	link("CmpPmenu", "Pmenu")
	link("CmpPmenuSel", "PmenuSel")
	link("CmpPmenuBorder", "FloatBorder")
end

local function setTelescope(transparent)
	local bg = transparent and "NONE" or colors.gutter

	hl("TelescopeNormal", { fg = colors.fg, bg = bg })
	hl("TelescopeBorder", { fg = colors.border, bg = bg })
	hl("TelescopePromptNormal", { fg = colors.fg, bg = bg })
	hl("TelescopePromptBorder", { fg = colors.border, bg = bg })

	hl("TelescopeSelection", { bg = colors.cursor })
	hl("TelescopeMatching", { fg = colors.type })

	hl("TelescopePromptTitle", { fg = colors.fg, bg = bg })
	hl("TelescopeResultsTitle", { fg = colors.dim, bg = bg })
	hl("TelescopePreviewTitle", { fg = colors.dim, bg = bg })
end

local function setCmpKinds()
	link("CmpItemAbbr", "Normal")
	hl("CmpItemAbbrMatch", { fg = colors.type })
	hl("CmpItemAbbrMatchFuzzy", { fg = colors.info })
	link("CmpItemMenu", "Comment")

	hl("CmpItemKind", { fg = colors.type })
	hl("CmpItemKindFunction", { fg = colors.func })
	hl("CmpItemKindMethod", { fg = colors.func })
	hl("CmpItemKindConstructor", { fg = colors.func })
	hl("CmpItemKindVariable", { fg = colors.ident })
	hl("CmpItemKindField", { fg = colors.ident })
	hl("CmpItemKindProperty", { fg = colors.ident })
	hl("CmpItemKindClass", { fg = colors.type })
	hl("CmpItemKindStruct", { fg = colors.type })
	hl("CmpItemKindInterface", { fg = colors.type })
	hl("CmpItemKindEnum", { fg = colors.type })
	hl("CmpItemKindKeyword", { fg = colors.keyword })
	hl("CmpItemKindSnippet", { fg = colors.qualifier })
end

local function setLuaSnip()
	hl("LuasnipInsertNode", { underline = true, sp = colors.type })
	hl("LuasnipChoiceNode", { underline = true, sp = colors.func })
	hl("LuasnipExitNode", { fg = colors.dim })
end

local function setTitles()
	hl("Directory", { fg = colors.type })
	hl("Title", { fg = colors.fg })
end

function M.colorscheme()
	vim.cmd("highlight clear")
	vim.cmd("syntax reset")

	vim.o.background = "dark"
	vim.g.colors_name = "bears-Forest"

	local transparentUI = false
	local transparentBG = false

	-- Lower blend keeps UI cleaner and more readable
	vim.o.winblend = transparentUI and 8 or 0
	vim.o.pumblend = transparentUI and 8 or 0

	setTransparent(transparentBG)

	setBasicColors(transparentBG)
	setCoreSyntax()
	setTreesitterAndLsp()

	setStatusAndTabs(transparentBG)
	setFloatAndPopup(transparentUI)
	setTelescope(transparentUI)
	setCmpKinds()
	setLuaSnip()
	setTitles()
end

return M
