-- Keys a guide (tmux/README.md, nvim/.config/nvim/README.md) cites that the
-- config doesn't have, one per line. The keys are the backquoted ones in
-- the first cell of each table row, written like the shortcut search shows
-- them; case only counts outside <...> (<C-h> is <C-H>, Q isn't q). Run
-- inside the sandbox's Neovim:
-- luaeval('dofile(_A[1])(_A[2])', ['<this file>', {readme, kind, tmux, prefix, allowed}])
-- kind "nvim" checks against Neovim's maps, "tmux" against the tmux keys in
-- the file `tmux` (list-keys -N -F output); `allowed` lists keys to accept

local function norm(key)
    return (key:gsub("<[^>]+>", string.lower))
end

return function(args)
    local s = require("config.shortcuts")
    local entries
    if args.kind == "tmux" then
        entries = s.parse_tmux(table.concat(vim.fn.readfile(args.tmux), "\n"), args.prefix)
    else
        entries = s.nvim_keys()
    end
    local known = {}
    for _, e in ipairs(entries) do
        known[norm(e.keys)] = true
    end
    for _, k in ipairs(args.allowed or {}) do
        known[norm(k)] = true
    end

    local missing, cited = {}, 0
    for line in table.concat(vim.fn.readfile(args.readme), "\n"):gmatch("[^\n]+") do
        -- Table rows, not the separator; an escaped pipe belongs to the cell
        if line:match("^|") and not line:match("^|%s*:?%-") then
            local row = line:gsub("\\|", "\1")
            local first = row:match("^|([^|]*)|") or ""
            for key in first:gmatch("`([^`]+)`") do
                key = key:gsub("\1", "|")
                cited = cited + 1
                if not known[norm(key)] then
                    table.insert(missing, key)
                end
            end
        end
    end
    if cited == 0 then
        return "no keys found in " .. args.readme
    end
    return table.concat(missing, "\n")
end
