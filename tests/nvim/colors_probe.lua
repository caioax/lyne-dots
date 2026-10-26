-- The colors nvim-colorizer.lua shows in the current buffer, as
-- text=rrggbb (the background it paints), one per line. Run inside the
-- sandbox's Neovim: luaeval('dofile(_A)', '<this file>')
local out = {}
for _, m in ipairs(vim.api.nvim_buf_get_extmarks(0, -1, 0, -1, { details = true })) do
	local d = m[4]
	if d.hl_group and d.hl_group:match("^colorizer") then
		local text = vim.api.nvim_buf_get_text(0, m[2], m[3], d.end_row, d.end_col, {})[1]
		local bg = vim.api.nvim_get_hl(0, { name = d.hl_group }).bg
		table.insert(out, text .. "=" .. (bg and string.format("%06x", bg) or "?"))
	end
end
return table.concat(out, "\n")
