-- Palette of the "lyne" colorscheme.
--
-- The shell (quickshell ThemeService) writes the current theme to
-- ~/.cache/lyne/nvim.json: the shell palette (surfaces, text, accent,
-- success/warning/error), the terminal colors (ANSI 0-15 + color16 orange)
-- and whether the background is transparent. Presets, custom themes and
-- Material You all arrive in that same shape, and this module maps it to the
-- semantic roles the highlight groups use.

local M = {}

M.path = (os.getenv("XDG_CACHE_HOME") or (os.getenv("HOME") .. "/.cache")) .. "/lyne/nvim.json"

-- Tokyo Night, used until the shell has written a theme
M.fallback = {
	palette = {
		background = "#1a1b26",
		surface0 = "#24283b",
		surface1 = "#292e42",
		surface2 = "#414868",
		surface3 = "#565f89",
		text = "#c0caf5",
		subtext = "#a9b1d6",
		accent = "#7aa2f7",
		success = "#9ece6a",
		warning = "#e0af68",
		error = "#f7768e",
		muted = "#545c7e",
		greyBlue = "#283457",
		blueDark = "#16161e",
	},
	terminal = {
		color1 = "#f7768e",
		color2 = "#9ece6a",
		color3 = "#e0af68",
		color4 = "#7aa2f7",
		color5 = "#bb9af7",
		color6 = "#7dcfff",
		color16 = "#ff9e64",
	},
	transparent = false,
}

-- Reads the theme the shell wrote; falls back per missing key
function M.read()
	local src = vim.deepcopy(M.fallback)
	local file = io.open(M.path, "r")
	if not file then
		return src
	end
	local ok, data = pcall(vim.json.decode, file:read("*a"))
	file:close()
	if not ok or type(data) ~= "table" then
		return src
	end
	for _, key in ipairs({ "palette", "terminal" }) do
		if type(data[key]) == "table" then
			src[key] = vim.tbl_extend("force", src[key], data[key])
		end
	end
	if data.transparent ~= nil then
		src.transparent = data.transparent == true
	end
	return src
end

local function rgb(hex)
	hex = hex:gsub("#", "")
	return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
end

-- Mixes `fg` over `bg`; alpha 1 = fg, 0 = bg
function M.blend(fg, bg, alpha)
	local r1, g1, b1 = rgb(fg)
	local r2, g2, b2 = rgb(bg)
	local function mix(a, b)
		return math.floor(a * alpha + b * (1 - alpha) + 0.5)
	end
	return string.format("#%02x%02x%02x", mix(r1, r2), mix(g1, g2), mix(b1, b2))
end

-- Relative luminance (0-1), to tell light themes apart
function M.luminance(hex)
	local r, g, b = rgb(hex)
	return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255
end

-- WCAG contrast ratio between two colors (1-21)
function M.contrast(a, b)
	local function linear(hex)
		local r, g, b2 = rgb(hex)
		local function ch(v)
			v = v / 255
			return v <= 0.03928 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4
		end
		return 0.2126 * ch(r) + 0.7152 * ch(g) + 0.0722 * ch(b2)
	end
	local la, lb = linear(a), linear(b)
	return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05)
end

local function to_hsl(hex)
	local r, g, b = rgb(hex)
	r, g, b = r / 255, g / 255, b / 255
	local max, min = math.max(r, g, b), math.min(r, g, b)
	local l = (max + min) / 2
	if max == min then
		return 0, 0, l
	end
	local d = max - min
	local s = l > 0.5 and d / (2 - max - min) or d / (max + min)
	local h
	if max == r then
		h = (g - b) / d + (g < b and 6 or 0)
	elseif max == g then
		h = (b - r) / d + 2
	else
		h = (r - g) / d + 4
	end
	return h / 6, s, l
end

local function from_hsl(h, s, l)
	local function hue(p, q, t)
		t = t % 1
		if t < 1 / 6 then
			return p + (q - p) * 6 * t
		elseif t < 1 / 2 then
			return q
		elseif t < 2 / 3 then
			return p + (q - p) * (2 / 3 - t) * 6
		end
		return p
	end
	local r, g, b = l, l, l
	if s > 0 then
		local q = l < 0.5 and l * (1 + s) or l + s - l * s
		local p = 2 * l - q
		r, g, b = hue(p, q, h + 1 / 3), hue(p, q, h), hue(p, q, h - 1 / 3)
	end
	return string.format(
		"#%02x%02x%02x",
		math.floor(r * 255 + 0.5),
		math.floor(g * 255 + 0.5),
		math.floor(b * 255 + 0.5)
	)
end

-- A color that reads on `bg` with at least `min` contrast: the color itself,
-- else its bright variant, else the better one with its lightness pushed away
-- from the background (same hue and saturation). Some themes pick dark ANSI
-- colors or faint comment colors
function M.readable(color, bright, bg, min)
	if M.contrast(color, bg) >= min then
		return color
	end
	if bright and M.contrast(bright, bg) > M.contrast(color, bg) then
		color = bright
	end
	local h, s, l = to_hsl(color)
	local step = M.luminance(bg) > 0.5 and -0.02 or 0.02
	while M.contrast(color, bg) < min and l > 0 and l < 1 do
		l = math.max(0, math.min(1, l + step))
		color = from_hsl(h, s, l)
	end
	return color
end

-- Minimum contrast against the background: syntax colors, and the dimmed
-- text of comments and line numbers (meant to stay quieter)
M.min_contrast = 4.5
M.min_contrast_dim = 3

-- Semantic roles used by the highlight groups and lualine
function M.build(src)
	local s = src.palette
	local raw = src.terminal
	local orange = raw.color16 or M.blend(raw.color1, raw.color3, 0.5)
	local function syntax(color, bright)
		return M.readable(color, bright, s.background, M.min_contrast)
	end
	local t = {
		color1 = syntax(raw.color1, raw.color9),
		color2 = syntax(raw.color2, raw.color10),
		color3 = syntax(raw.color3, raw.color11),
		color4 = syntax(raw.color4, raw.color12),
		color5 = syntax(raw.color5, raw.color13),
		color6 = syntax(raw.color6, raw.color14),
		color16 = syntax(orange),
	}
	local p = {
		transparent = src.transparent,

		-- Backgrounds, from darkest to lightest (on dark themes)
		bg = s.background,
		bg_dark = s.blueDark,
		bg_popup = s.surface0,
		bg_float = s.surface1,
		bg_visual = s.greyBlue,

		-- Text
		fg = s.text,
		fg_sub = s.subtext,
		fg_dim = M.readable(s.surface3, nil, s.background, M.min_contrast_dim),
		fg_gutter = s.surface2,
		muted = s.muted,

		accent = s.accent,
		border = s.accent,

		-- Syntax, from the terminal colors
		func = t.color4,
		keyword = t.color5,
		string = t.color2,
		class = t.color16,
		number = t.color16,
		yellow = t.color3,
		property = t.color6,
		red = t.color1,

		-- States
		error = s.error,
		diag_err = s.error,
		diag_warn = s.warning,
		diag_info = s.accent,
		diag_hint = t.color6,
		git_add = s.success,
		git_change = s.warning,
		git_del = s.error,

		guide = s.surface2,
		scope = s.surface3,
	}
	p.light = M.luminance(p.bg) > 0.5
	return p
end

return M
