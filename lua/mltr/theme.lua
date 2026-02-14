local M = {}

local colors = {
	-- Base
	bg = "#1B1B1B",
	fg = "#D0C8BE",

	gutter = "#24211C",
	border = "#2E2A25",

	-- Dim iets koeler zodat UI/secondary niet zo warm-muddy wordt
	dim = "#9B9FA0",

	-- Syntax
	comment = "#6F685E",

	-- Strings: lichter + iets cleaner groen (meer “leaf/sage”)
	string = "#97B983",

	-- Warme as (blijft jouw identiteit)
	keyword = "#D08A3F",
	func = "#E16A2D",
	ident = "#c9af79",

	-- Koele as: types duidelijker koel/teal (meer contrast met keyword/ident)
	type = "#76BFC0",

	-- Constants / numbers: klein beetje richting “natuur/steen”
	constant = "#8F3A3A",
	number = "#B7C79B",

	-- Params: naast ident, maar iets koeler/ivory zodat ze “input” voelen
	param = "#c9a965",

	-- UI
	visual = "#3B3028",
	error = "#A14C4C",

	-- Details
	cursor = "#232323",
	lineNr = "#6A635A",
	split = "#2F2F2F",
	eob = "#2A2A2A",

	-- (optioneel, handig later voor diagnostics; koel/warm balans)
	info = "#7AA7C7",
	hint = "#7FBDA6",
	warn = "#C9A25A",
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
	-- Important: if transparent, keep bg NONE for Normal/NormalNC
	local bg = transparent and "NONE" or colors.bg

	hl("Normal", { fg = colors.fg, bg = bg })
	hl("NormalNC", { fg = colors.fg, bg = bg })
	hl("CursorLine", { bg = colors.cursor })
	hl("Visual", { bg = colors.visual })
	hl("LineNr", { fg = colors.lineNr })
	hl("CursorLineNr", { fg = colors.fg, bold = true })
	hl("VertSplit", { fg = colors.split, bg = bg })
	hl("SignColumn", { bg = bg })
	hl("EndOfBuffer", { fg = colors.eob })
end

local function setCoreSyntax()
	-- Classic groups
	hl("Comment", { fg = colors.comment, italic = true })
	hl("String", { fg = colors.string })
	hl("Character", { fg = colors.string })
	hl("Number", { fg = colors.number })
	hl("Boolean", { fg = colors.constant, bold = true })
	hl("Constant", { fg = colors.constant })

	hl("Identifier", { fg = colors.ident })
	hl("Function", { fg = colors.func, bold = true })

	hl("Statement", { fg = colors.keyword, bold = true })
	hl("Keyword", { fg = colors.keyword, bold = true })
	hl("Operator", { fg = colors.fg })

	hl("Type", { fg = colors.type })
	hl("Special", { fg = colors.constant })

	hl("Error", { fg = colors.error, bold = true })

	hl("DiagnosticError", { fg = colors.error })
	hl("DiagnosticWarn", { fg = colors.warn })
	hl("DiagnosticInfo", { fg = colors.info })
	hl("DiagnosticHint", { fg = colors.hint })

	hl("DiagnosticVirtualTextError", { fg = colors.error })
	hl("DiagnosticVirtualTextWarn", { fg = colors.warn })
	hl("DiagnosticVirtualTextInfo", { fg = colors.info })
	hl("DiagnosticVirtualTextHint", { fg = colors.hint })

	-- Optional: subtle dim for delimiters
	hl("Delimiter", { fg = colors.fg })
end

local function setTreesitterAndLsp()
	-- Treesitter basics
	link("@comment", "Comment")
	link("@string", "String")
	link("@character", "Character")
	link("@number", "Number")
	link("@constant", "Constant")
	link("@type", "Type")
	link("@function", "Function")
	link("@keyword", "Keyword")
	link("@operator", "Operator")

	-- Variables / identifiers
	link("@variable", "Identifier")
	link("@variable.builtin", "Identifier")

	-- New: parameters (your request)
	hl("Parameter", { fg = colors.param, italic = true })
	link("@parameter", "Parameter")
	link("@variable.parameter", "Parameter")
	link("@lsp.type.parameter", "Parameter")

	-- Punctuation
	hl("@punctuation", { fg = colors.fg })
	hl("@punctuation.delimiter", { fg = colors.fg })
	hl("@punctuation.bracket", { fg = colors.fg })

	hl("RainbowDelimiterYellow", { fg = colors.keyword })
	hl("RainbowDelimiterOrange", { fg = colors.func })
	hl("RainbowDelimiterCyan", { fg = colors.type })
	hl("RainbowDelimiterBlue", { fg = colors.dim })
	hl("RainbowDelimiterViolet", { fg = colors.ident })

	-- We force them to keyword-color so .cpp and .hpp match.
	hl("@keyword.operator", { fg = colors.keyword, bold = true })
	hl("@lsp.type.keyword", { fg = colors.keyword, bold = true })

	-- Some setups mark 'new'/'delete' as operator semantic tokens:
	hl("@lsp.type.operator", { fg = colors.keyword, bold = true })
end

local function setStatusAndTabs(transparent)
	local bg = transparent and "NONE" or colors.gutter
	local mainbg = transparent and "NONE" or colors.bg

	hl("StatusLine", { fg = colors.fg, bg = bg })
	hl("StatusLineNC", { fg = colors.dim, bg = bg })
	hl("WinSeparator", { fg = colors.border, bg = mainbg })

	hl("TabLine", { fg = colors.dim, bg = bg })
	hl("TabLineSel", { fg = colors.fg, bg = mainbg, bold = true })
	hl("TabLineFill", { bg = bg })
end

local function setFloatAndPopup(transparent)
	local bg = transparent and "NONE" or colors.gutter

	hl("NormalFloat", { fg = colors.fg, bg = bg })
	hl("FloatBorder", { fg = colors.border, bg = bg })

	hl("Pmenu", { fg = colors.fg, bg = bg })
	hl("PmenuSel", { fg = colors.bg, bg = colors.keyword, bold = true })
	hl("PmenuSbar", { bg = bg })
	hl("PmenuThumb", { bg = colors.border })

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

	hl("TelescopeSelection", { bg = colors.visual })
	hl("TelescopeMatching", { fg = colors.keyword, bold = true })

	hl("TelescopePromptTitle", { fg = colors.bg, bg = colors.keyword, bold = true })
	hl("TelescopeResultsTitle", { fg = colors.bg, bg = colors.border, bold = true })
	hl("TelescopePreviewTitle", { fg = colors.bg, bg = colors.func, bold = true })
end

local function setCmpKinds()
	-- Completion menu kinds
	link("CmpItemAbbr", "Normal")
	link("CmpItemAbbrMatch", "Identifier")
	link("CmpItemAbbrMatchFuzzy", "Identifier")
	link("CmpItemMenu", "Comment")

	link("CmpItemKind", "Type")
	link("CmpItemKindFunction", "Function")
	link("CmpItemKindVariable", "Identifier")
	link("CmpItemKindSnippet", "Special")
end

local function setLuaSnip()
	hl("LuasnipInsertNode", { underline = true, sp = colors.keyword })
	hl("LuasnipChoiceNode", { underline = true, sp = colors.func })
	hl("LuasnipExitNode", { fg = colors.dim })
end

local function setTitles()
	hl("Directory", { fg = colors.func, bold = true })
	hl("Title", { fg = colors.func, bold = true })
end

function M.colorscheme()
	vim.cmd("highlight clear")
	vim.cmd("syntax reset")

	vim.o.background = "dark"
	vim.g.colors_name = "bears-Forest"

	local transparentUI = true
	local transparentBG = false

	-- Blend controls (popup transparency)
	vim.o.winblend = transparentUI and 15 or 0
	vim.o.pumblend = transparentUI and 15 or 0

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
