-- Maps the config makes (global ones and the current buffer's: LSP, git)
-- that have no desc, one per line as "mode lhs (file)". Maps from lazy.nvim's
-- `keys` count too: lazy.nvim defines them with the spec's desc. Run inside
-- the sandbox's Neovim: luaeval('dofile(_A)', '<this file>')

local config = vim.fn.resolve(vim.fn.stdpath("config"))

local function origin(m)
    local file = ""
    if m.callback then
        file = debug.getinfo(m.callback, "S").source:gsub("^@", "")
    elseif m.sid and m.sid > 0 then
        local info = vim.fn.getscriptinfo({ sid = m.sid })[1]
        file = info and info.name or ""
    end
    file = vim.fn.resolve(file)
    if file:sub(1, #config) == config then
        return file:sub(#config + 2)
    end
    if file:match("lazy%.nvim/lua/lazy/core/handler/keys%.lua$") then
        return "lazy.nvim keys"
    end
    return nil
end

local missing = {}
for _, mode in ipairs({ "n", "v", "x", "o", "i", "t" }) do
    local maps = vim.list_extend(vim.api.nvim_get_keymap(mode), vim.api.nvim_buf_get_keymap(0, mode))
    for _, m in ipairs(maps) do
        local from = origin(m)
        if from and not m.lhs:match("^<Plug>") and (m.desc == nil or m.desc == "") then
            table.insert(missing, string.format("%s %s (%s)", mode, vim.fn.keytrans(vim.keycode(m.lhs)), from))
        end
    end
end
table.sort(missing)
return table.concat(missing, "\n")
