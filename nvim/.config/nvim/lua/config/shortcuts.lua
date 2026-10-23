-- Search every shortcut in one Telescope list: Neovim's maps (with a desc,
-- the LSP and git ones of config/buffer_keys.lua included) and, inside tmux,
-- tmux's keys with a note (list-keys -N). Read from the running config, so
-- it never falls behind it. Opened with tmux's prefix + ? (a popup that
-- quits with the list), <leader>fk or :Shortcuts

local M = {}

local MODES = {
	n = "normal",
	v = "visual",
	x = "visual",
	s = "select",
	o = "operator",
	i = "insert",
	c = "command line",
	t = "terminal",
}

local TMUX_FORMAT = "#{key_table}\t#{key_string}\t#{key_note}"

-- "<leader>ff" when the leader is Space, "<C-H>" for Ctrl+h. keytrans names
-- Ctrl+j by its byte (<NL>): shown as the key people press
local function show_lhs(lhs)
	local leader = vim.g.mapleader or "\\"
	local keys
	if lhs:sub(1, #leader) == leader then
		keys = "<leader>" .. vim.fn.keytrans(vim.keycode(lhs:sub(#leader + 1)))
	else
		keys = vim.fn.keytrans(vim.keycode(lhs))
	end
	return (keys:gsub("<NL>", "<C-J>"))
end

-- Where a map made with a function was made ("lua/config/keymaps.lua:12"
-- inside the config). Maps whose rhs is text show what they run instead: for
-- those made from Lua, Neovim only knows the first script (init.lua)
local function origin(m)
	if not m.callback then
		return nil
	end
	local config = vim.fn.resolve(vim.fn.stdpath("config"))
	local info = debug.getinfo(m.callback, "S")
	local file, line = vim.fn.resolve((info.source:gsub("^@", ""))), info.linedefined
	if file:sub(1, #config) == config then
		file = file:sub(#config + 2)
	elseif file:match("/lazy/core/handler/keys%.lua$") then
		return "lazy.nvim keys of a plugin spec"
	end
	if file == "" then
		return nil
	end
	return line and line > 0 and (file .. ":" .. line) or file
end

-- Neovim's global maps with a desc, one entry per lhs + desc (modes merged),
-- then the buffer keys of config/buffer_keys.lua
function M.nvim_keys()
	local out, index = {}, {}
	for _, mode in ipairs({ "n", "v", "o", "i", "c", "t" }) do
		for _, m in ipairs(vim.api.nvim_get_keymap(mode)) do
			if m.desc and m.desc ~= "" and not m.lhs:match("^<Plug>") and not m.lhs:match("^<SNR>") then
				local keys = show_lhs(m.lhs)
				local id = keys .. "\0" .. m.desc
				local entry = index[id]
				if not entry then
					entry = {
						source = "nvim",
						keys = keys,
						desc = m.desc,
						modes = {},
						runs = m.rhs and m.rhs ~= "" and m.rhs or nil,
						from = origin(m),
					}
					index[id] = entry
					table.insert(out, entry)
				end
				local name = MODES[mode] or mode
				if not vim.tbl_contains(entry.modes, name) then
					table.insert(entry.modes, name)
				end
			end
		end
	end
	for _, e in ipairs(out) do
		e.where = table.concat(e.modes, ", ")
	end
	table.sort(out, function(a, b)
		return a.keys:lower() < b.keys:lower()
	end)

	local buffer_keys = require("config.buffer_keys")
	for _, list in ipairs({ "lsp", "git" }) do
		for _, k in ipairs(buffer_keys[list]) do
			table.insert(out, {
				source = "nvim",
				keys = show_lhs(vim.keycode(k[2])),
				desc = k[4],
				where = buffer_keys.labels[list],
				from = "lua/config/buffer_keys.lua",
			})
		end
	end
	return out
end

-- `tmux list-keys -N -F TMUX_FORMAT` output: one entry per key with a note.
-- `prefix` is the prefix key's name ("C-Space")
function M.parse_tmux(text, prefix)
	local out = {}
	for line in (text or ""):gmatch("[^\n]+") do
		local tbl, key, note = line:match("^([^\t]+)\t([^\t]+)\t(.*)$")
		if tbl and vim.trim(note) ~= "" then
			local entry = { source = "tmux", desc = vim.trim(note) }
			if tbl == "root" then
				entry.keys, entry.where = key, "no prefix"
			elseif tbl == "prefix" then
				entry.keys, entry.where = (prefix ~= "" and prefix or "prefix") .. " " .. key, "after the prefix"
			elseif tbl:match("^copy%-mode") then
				entry.keys, entry.where = key, "copy mode"
			else
				entry.keys, entry.where = key, tbl
			end
			table.insert(out, entry)
		end
	end
	return out
end

-- tmux's keys, only inside tmux
function M.tmux_keys()
	if not vim.env.TMUX or vim.fn.executable("tmux") == 0 then
		return {}
	end
	local function run(args)
		local result = vim.system(args, { text = true }):wait()
		return result.code == 0 and result.stdout or ""
	end
	local text = run({ "tmux", "list-keys", "-N", "-F", TMUX_FORMAT })
		.. run({ "tmux", "list-keys", "-N", "-F", TMUX_FORMAT, "-T", "copy-mode-vi" })
	return M.parse_tmux(text, vim.trim(run({ "tmux", "show-options", "-gv", "prefix" })))
end

function M.entries()
	return vim.list_extend(M.nvim_keys(), M.tmux_keys())
end

local function details(e)
	local lines = {
		"Keys:   " .. e.keys,
		"Does:   " .. e.desc,
	}
	if e.source == "tmux" then
		table.insert(lines, "Where:  tmux, " .. e.where)
	elseif e.where == "LSP" then
		table.insert(lines, "Where:  Neovim, buffers with a language server")
	elseif e.where == "Git" then
		table.insert(lines, "Where:  Neovim, files under git")
	else
		table.insert(lines, "Where:  Neovim, " .. e.where .. " mode")
	end
	if e.runs then
		table.insert(lines, "Runs:   " .. e.runs)
	end
	if e.from then
		table.insert(lines, "From:   " .. e.from)
	end
	return lines
end

-- opts.quit: quit Neovim when the list closes (tmux's popup)
function M.pick(opts)
	opts = opts or {}
	if opts.quit and vim.v.vim_did_enter == 0 then
		require("config.popup").start(function()
			M.pick(opts)
		end)
		return
	end
	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local previewers = require("telescope.previewers")
	local actions = require("telescope.actions")
	local conf = require("telescope.config").values
	local entry_display = require("telescope.pickers.entry_display")

	local displayer = entry_display.create({
		separator = "  ",
		items = { { width = 4 }, { width = 20 }, { remaining = true } },
	})

	pickers
		.new({}, {
			prompt_title = "Shortcuts (Neovim and tmux)",
			finder = finders.new_table({
				results = M.entries(),
				entry_maker = function(e)
					return {
						value = e,
						ordinal = table.concat({ e.source, e.keys, e.desc, e.where }, " "),
						display = function()
							return displayer({
								{ e.source, e.source == "tmux" and "Constant" or "Function" },
								{ e.keys, "Special" },
								{ e.desc .. "  · " .. e.where, "Normal" },
							})
						end,
					}
				end,
			}),
			sorter = conf.generic_sorter({}),
			previewer = previewers.new_buffer_previewer({
				title = "Shortcut",
				define_preview = function(self, entry)
					vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, details(entry.value))
				end,
			}),
			attach_mappings = function(prompt_bufnr, map)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
				end)
				-- A search to look something up: one Escape leaves it
				map("i", "<Esc>", actions.close)
				if opts.quit then
					require("config.popup").quit_on_close(actions)
				end
				return true
			end,
		})
		:find()
end

return M
