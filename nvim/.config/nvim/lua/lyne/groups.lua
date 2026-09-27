-- Highlight groups of the "lyne" colorscheme, built from the semantic
-- palette (lyne.palette.build). The UI/plugin choices come from the old
-- tokyonight on_highlights customization, so every theme gets that look.

local blend = require("lyne.palette").blend

return function(p)
	-- The editor background; floats and sidebars stay solid when transparent
	local bg = p.transparent and "NONE" or p.bg
	local bg_side = p.transparent and "NONE" or p.bg_dark

	-- Soft tints for diffs, virtual text and search matches
	local function tint(color, alpha)
		return blend(color, p.bg, alpha or 0.15)
	end

	return {
		-- ====================================================================
		-- EDITOR
		-- ====================================================================
		Normal = { fg = p.fg, bg = bg },
		NormalNC = { fg = p.fg, bg = bg },
		NormalSB = { fg = p.fg_sub, bg = bg_side },
		NormalFloat = { fg = p.fg, bg = p.bg_float },
		FloatBorder = { fg = p.border, bg = p.bg_float },
		FloatTitle = { fg = p.border, bg = p.bg_float, bold = true },
		FloatFooter = { fg = p.fg_dim, bg = p.bg_float },

		Cursor = { fg = p.bg, bg = p.func },
		lCursor = { fg = p.bg, bg = p.fg },
		CursorIM = { fg = p.bg, bg = p.fg },
		CursorLine = { bg = p.bg_float },
		CursorColumn = { bg = p.bg_float },
		ColorColumn = { bg = p.bg_popup },
		CursorLineNr = { fg = p.class, bold = true },
		LineNr = { fg = p.fg_dim },
		LineNrAbove = { fg = p.fg_dim },
		LineNrBelow = { fg = p.fg_dim },
		SignColumn = { bg = "NONE" },
		SignColumnSB = { bg = bg_side },
		FoldColumn = { fg = p.fg_dim, bg = "NONE" },
		Folded = { fg = p.func, bg = p.bg_popup },
		EndOfBuffer = { fg = p.bg },
		NonText = { fg = p.fg_gutter },
		Whitespace = { fg = p.fg_gutter },
		SpecialKey = { fg = p.fg_gutter },
		Conceal = { fg = p.fg_dim },

		Visual = { bg = p.bg_visual },
		VisualNOS = { bg = p.bg_visual },
		Search = { fg = p.bg, bg = p.number },
		IncSearch = { fg = p.bg, bg = p.class },
		CurSearch = { fg = p.bg, bg = p.class },
		Substitute = { fg = p.bg, bg = p.red },
		MatchParen = { fg = p.class, bold = true, underline = true },
		QuickFixLine = { bg = p.bg_visual, bold = true },

		WinSeparator = { fg = p.border },
		VertSplit = { fg = p.border },
		StatusLine = { fg = p.fg_sub, bg = p.bg_dark },
		StatusLineNC = { fg = p.fg_gutter, bg = p.bg_dark },
		WinBar = { fg = p.fg_sub, bg = "NONE" },
		WinBarNC = { fg = p.fg_dim, bg = "NONE" },
		TabLine = { fg = p.fg_dim, bg = p.bg_dark },
		TabLineFill = { bg = p.bg_dark },
		TabLineSel = { fg = p.bg, bg = p.accent },

		Pmenu = { fg = p.fg_dim, bg = p.bg_float },
		PmenuSel = { fg = p.fg, bg = p.bg_visual, bold = true },
		PmenuMatch = { fg = p.func, bold = true },
		PmenuMatchSel = { fg = p.func, bold = true },
		PmenuSbar = { bg = p.bg_float },
		PmenuThumb = { bg = p.border },
		WildMenu = { bg = p.bg_visual },

		Directory = { fg = p.func },
		Title = { fg = p.func, bold = true },
		Question = { fg = p.func },
		ModeMsg = { fg = p.fg_sub, bold = true },
		MsgArea = { fg = p.fg_sub },
		MoreMsg = { fg = p.func },
		ErrorMsg = { fg = p.diag_err },
		WarningMsg = { fg = p.diag_warn },

		SpellBad = { sp = p.diag_err, undercurl = true },
		SpellCap = { sp = p.diag_warn, undercurl = true },
		SpellLocal = { sp = p.diag_info, undercurl = true },
		SpellRare = { sp = p.diag_hint, undercurl = true },

		DiffAdd = { bg = tint(p.git_add, 0.2) },
		DiffChange = { bg = tint(p.git_change, 0.12) },
		DiffDelete = { bg = tint(p.git_del, 0.2) },
		DiffText = { bg = tint(p.git_change, 0.3) },
		diffAdded = { fg = p.git_add },
		diffRemoved = { fg = p.git_del },
		diffChanged = { fg = p.git_change },
		diffOldFile = { fg = p.yellow },
		diffNewFile = { fg = p.class },
		diffFile = { fg = p.func },
		diffLine = { fg = p.fg_dim },
		diffIndexLine = { fg = p.keyword },

		-- ====================================================================
		-- SYNTAX
		-- ====================================================================
		Comment = { fg = p.fg_dim, italic = true },
		String = { fg = p.string },
		Character = { fg = p.string },
		Number = { fg = p.number },
		Float = { fg = p.number },
		Boolean = { fg = p.number, bold = true },
		Constant = { fg = p.number },

		Function = { fg = p.func, bold = true },
		Identifier = { fg = p.fg },

		Keyword = { fg = p.keyword, italic = true },
		Statement = { fg = p.keyword },
		Conditional = { fg = p.keyword },
		Repeat = { fg = p.keyword },
		Label = { fg = p.property },
		Exception = { fg = p.keyword },

		Operator = { fg = p.fg_dim },
		Type = { fg = p.class },
		StorageClass = { fg = p.keyword },
		Structure = { fg = p.class },
		Typedef = { fg = p.class },
		Delimiter = { fg = p.fg_dim },

		PreProc = { fg = p.property },
		Include = { fg = p.keyword },
		Define = { fg = p.keyword },
		Macro = { fg = p.number },
		Special = { fg = p.property },
		SpecialChar = { fg = p.property },
		Tag = { fg = p.class },
		Debug = { fg = p.class },
		Underlined = { underline = true },
		Bold = { bold = true },
		Italic = { italic = true },
		Error = { fg = p.diag_err },
		Todo = { fg = p.bg, bg = p.yellow, bold = true },

		-- ====================================================================
		-- TREESITTER
		-- ====================================================================
		["@variable"] = { fg = p.fg },
		["@variable.builtin"] = { fg = p.keyword },
		["@variable.parameter"] = { fg = p.number },
		["@variable.parameter.builtin"] = { fg = p.number },
		["@variable.member"] = { fg = p.property },
		["@property"] = { fg = p.property },

		["@function"] = { fg = p.func, bold = true },
		["@function.call"] = { fg = p.func },
		["@function.builtin"] = { fg = p.func },
		["@function.method"] = { fg = p.func, bold = true },
		["@function.method.call"] = { fg = p.func },
		["@function.macro"] = { fg = p.number },
		["@constructor"] = { fg = p.class },

		["@type"] = { fg = p.class },
		["@type.builtin"] = { fg = p.class },
		["@type.definition"] = { fg = p.class },
		["@module"] = { fg = p.class },
		["@module.builtin"] = { fg = p.keyword },
		["@attribute"] = { fg = p.property },
		["@label"] = { fg = p.property },

		["@keyword"] = { fg = p.keyword, italic = true },
		["@keyword.import"] = { fg = p.keyword, italic = true },
		["@keyword.function"] = { fg = p.keyword, italic = true },
		["@keyword.return"] = { fg = p.keyword, italic = true },
		["@keyword.operator"] = { fg = p.keyword },
		["@keyword.conditional"] = { fg = p.keyword },
		["@keyword.repeat"] = { fg = p.keyword },
		["@keyword.exception"] = { fg = p.keyword },

		["@constant"] = { fg = p.number },
		["@constant.builtin"] = { fg = p.number, bold = true },
		["@string"] = { fg = p.string },
		["@string.escape"] = { fg = p.property },
		["@string.regexp"] = { fg = p.property },
		["@string.special.url"] = { fg = p.property, underline = true },
		["@number"] = { fg = p.number },
		["@boolean"] = { fg = p.number, bold = true },
		["@operator"] = { fg = p.fg_dim },

		["@tag"] = { fg = p.class },
		["@tag.attribute"] = { fg = p.property },
		["@tag.delimiter"] = { fg = p.fg_dim },

		["@punctuation.delimiter"] = { fg = p.fg_dim },
		["@punctuation.bracket"] = { fg = p.fg_dim },
		["@punctuation.special"] = { fg = p.property },

		["@comment"] = { link = "Comment" },
		["@comment.error"] = { fg = p.bg, bg = p.diag_err },
		["@comment.warning"] = { fg = p.bg, bg = p.diag_warn },
		["@comment.todo"] = { link = "Todo" },
		["@comment.note"] = { fg = p.bg, bg = p.diag_hint },

		["@markup.heading"] = { fg = p.func, bold = true },
		["@markup.strong"] = { bold = true },
		["@markup.italic"] = { italic = true },
		["@markup.strikethrough"] = { strikethrough = true },
		["@markup.underline"] = { underline = true },
		["@markup.link"] = { fg = p.property },
		["@markup.link.label"] = { fg = p.property },
		["@markup.link.url"] = { fg = p.property, underline = true },
		["@markup.raw"] = { fg = p.string },
		["@markup.list"] = { fg = p.class },
		["@markup.quote"] = { fg = p.fg_sub, italic = true },

		["@diff.plus"] = { fg = p.git_add },
		["@diff.minus"] = { fg = p.git_del },
		["@diff.delta"] = { fg = p.git_change },

		-- LSP semantic tokens that would override treesitter with other colors
		["@lsp.type.namespace"] = { link = "@module" },
		["@lsp.type.parameter"] = { link = "@variable.parameter" },
		["@lsp.type.property"] = { link = "@property" },
		["@lsp.type.variable"] = {},
		["@lsp.type.enumMember"] = { link = "@constant" },
		["@lsp.typemod.function.defaultLibrary"] = { link = "@function.builtin" },
		["@lsp.typemod.variable.defaultLibrary"] = { link = "@variable.builtin" },

		-- ====================================================================
		-- LSP & DIAGNOSTICS
		-- ====================================================================
		LspReferenceText = { bg = p.bg_float },
		LspReferenceRead = { bg = p.bg_float },
		LspReferenceWrite = { bg = p.bg_float },
		LspSignatureActiveParameter = { bg = p.bg_visual, bold = true },
		LspInlayHint = { fg = p.fg_gutter, bg = tint(p.fg_gutter, 0.1) },
		LspCodeLens = { fg = p.fg_dim },
		LspInfoBorder = { fg = p.border, bg = p.bg_float },

		DiagnosticError = { fg = p.diag_err },
		DiagnosticWarn = { fg = p.diag_warn },
		DiagnosticInfo = { fg = p.diag_info },
		DiagnosticHint = { fg = p.diag_hint },
		DiagnosticOk = { fg = p.git_add },
		DiagnosticUnnecessary = { fg = p.fg_dim },
		DiagnosticVirtualTextError = { fg = p.diag_err, bg = tint(p.diag_err, 0.1) },
		DiagnosticVirtualTextWarn = { fg = p.diag_warn, bg = tint(p.diag_warn, 0.1) },
		DiagnosticVirtualTextInfo = { fg = p.diag_info, bg = tint(p.diag_info, 0.1) },
		DiagnosticVirtualTextHint = { fg = p.diag_hint, bg = tint(p.diag_hint, 0.1) },
		DiagnosticUnderlineError = { undercurl = true, sp = p.diag_err },
		DiagnosticUnderlineWarn = { undercurl = true, sp = p.diag_warn },
		DiagnosticUnderlineInfo = { undercurl = true, sp = p.diag_info },
		DiagnosticUnderlineHint = { undercurl = true, sp = p.diag_hint },

		healthError = { fg = p.diag_err },
		healthSuccess = { fg = p.git_add },
		healthWarning = { fg = p.diag_warn },

		-- ====================================================================
		-- PLUGINS
		-- ====================================================================
		-- Telescope
		TelescopeNormal = { fg = p.fg, bg = p.bg_dark },
		TelescopeBorder = { fg = p.border, bg = p.bg_dark },
		TelescopePromptNormal = { fg = p.fg, bg = p.bg_float },
		TelescopePromptBorder = { fg = p.func, bg = p.bg_float },
		TelescopePromptTitle = { fg = p.bg, bg = p.func, bold = true },
		TelescopePromptPrefix = { fg = p.func, bg = p.bg_float },
		TelescopePreviewTitle = { fg = p.bg, bg = p.string, bold = true },
		TelescopeResultsTitle = { fg = p.bg_dark, bg = p.bg_dark },
		TelescopeSelection = { fg = p.class, bg = p.bg_visual },
		TelescopeMatching = { fg = p.func, bold = true },

		-- nvim-cmp
		CmpItemAbbr = { fg = p.fg },
		CmpItemAbbrDeprecated = { fg = p.fg_dim, strikethrough = true },
		CmpItemAbbrMatch = { fg = p.func, bold = true },
		CmpItemAbbrMatchFuzzy = { fg = p.func, bold = true },
		CmpItemMenu = { fg = p.fg_dim },
		CmpItemKind = { fg = p.class },
		CmpItemKindFunction = { fg = p.func },
		CmpItemKindMethod = { fg = p.func },
		CmpItemKindVariable = { fg = p.property },
		CmpItemKindField = { fg = p.property },
		CmpItemKindProperty = { fg = p.property },
		CmpItemKindKeyword = { fg = p.keyword },
		CmpItemKindSnippet = { fg = p.string },
		CmpItemKindText = { fg = p.fg_sub },
		CmpGhostText = { fg = p.fg_gutter },

		-- GitSigns
		GitSignsAdd = { fg = p.git_add, bg = "NONE" },
		GitSignsChange = { fg = p.git_change, bg = "NONE" },
		GitSignsDelete = { fg = p.git_del, bg = "NONE" },
		GitSignsCurrentLineBlame = { fg = p.fg_gutter },

		-- Snacks
		SnacksIndent = { fg = p.guide },
		SnacksIndentScope = { fg = p.scope },
		SnacksDashboardHeader = { fg = p.func },
		SnacksDashboardIcon = { fg = p.func },
		SnacksDashboardDesc = { fg = p.fg },
		SnacksDashboardKey = { fg = p.number, bold = true },
		SnacksDashboardFooter = { fg = p.fg_dim },
		SnacksDashboardSpecial = { fg = p.string },
		SnacksNotifierBorderInfo = { fg = p.diag_info, bg = p.bg_float },
		SnacksNotifierBorderWarn = { fg = p.diag_warn, bg = p.bg_float },
		SnacksNotifierBorderError = { fg = p.diag_err, bg = p.bg_float },
		SnacksInputBorder = { fg = p.border, bg = p.bg_float },
		SnacksInputTitle = { fg = p.border, bg = p.bg_float, bold = true },

		-- Neo-tree
		NeoTreeNormal = { fg = p.fg, bg = p.bg_dark },
		NeoTreeNormalNC = { fg = p.fg, bg = p.bg_dark },
		NeoTreeWinSeparator = { fg = p.bg_dark, bg = p.bg_dark },
		NeoTreeEndOfBuffer = { fg = p.bg_dark, bg = p.bg_dark },
		NeoTreeCursorLine = { bg = p.bg_float, bold = true },
		NeoTreeRootName = { fg = p.fg, bold = true, italic = true },
		NeoTreeDirectoryName = { fg = p.func, bold = true },
		NeoTreeDirectoryIcon = { fg = p.func },
		NeoTreeFileName = { fg = p.fg },
		NeoTreeGitAdded = { fg = p.git_add },
		NeoTreeGitModified = { fg = p.git_change },
		NeoTreeGitDeleted = { fg = p.git_del },
		NeoTreeGitConflict = { fg = p.error, bold = true },
		NeoTreeGitUntracked = { fg = p.fg_dim, italic = true },
		NeoTreeIndentMarker = { fg = p.guide },
		NeoTreeExpander = { fg = p.fg_dim },
		NeoTreeSymbolicLinkTarget = { fg = p.property },
		NeoTreeFloatBorder = { fg = p.border, bg = p.bg_float },
		NeoTreeTitleBar = { fg = p.bg, bg = p.border },

		-- render-markdown
		RenderMarkdownH1Bg = { bg = tint(p.func, 0.15) },
		RenderMarkdownH2Bg = { bg = tint(p.class, 0.15) },
		RenderMarkdownH3Bg = { bg = tint(p.string, 0.15) },
		RenderMarkdownH4Bg = { bg = tint(p.property, 0.15) },
		RenderMarkdownH5Bg = { bg = tint(p.keyword, 0.15) },
		RenderMarkdownH6Bg = { bg = tint(p.yellow, 0.15) },
		RenderMarkdownH1 = { fg = p.func, bold = true },
		RenderMarkdownH2 = { fg = p.class, bold = true },
		RenderMarkdownH3 = { fg = p.string, bold = true },
		RenderMarkdownH4 = { fg = p.property, bold = true },
		RenderMarkdownH5 = { fg = p.keyword, bold = true },
		RenderMarkdownH6 = { fg = p.yellow, bold = true },
		RenderMarkdownCode = { bg = p.bg_popup },
		RenderMarkdownCodeInline = { bg = p.bg_popup },
		RenderMarkdownBullet = { fg = p.class },

		-- lazy.nvim / mason
		LazyNormal = { fg = p.fg, bg = p.bg_float },
		LazyButton = { fg = p.fg_sub, bg = p.bg_popup },
		LazyButtonActive = { fg = p.bg, bg = p.accent, bold = true },
		LazyH1 = { fg = p.bg, bg = p.accent, bold = true },
		LazySpecial = { fg = p.func },
		MasonNormal = { fg = p.fg, bg = p.bg_float },
		MasonHeader = { fg = p.bg, bg = p.accent, bold = true },
		MasonHighlight = { fg = p.func },
		MasonHighlightBlockBold = { fg = p.bg, bg = p.func, bold = true },
		MasonMuted = { fg = p.fg_dim },

		-- mini.icons / devicons keep their own colors
	}
end
