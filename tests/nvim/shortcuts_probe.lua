-- What tests/nvim/shortcuts.sh checks in config.shortcuts, as "name=value"
-- lines. Run inside the sandbox's Neovim:
-- luaeval('dofile(_A[1])(_A[2])', ['<this file>', '<tmux fixture>'])

return function(fixture)
    local s = require("config.shortcuts")
    local out = {}
    local function put(name, value)
        table.insert(out, name .. "=" .. tostring(value))
    end

    local tmux = s.parse_tmux(table.concat(vim.fn.readfile(fixture), "\n"), "C-Space")
    put("tmux.count", #tmux)
    for _, e in ipairs(tmux) do
        put("tmux[" .. e.keys .. "]", e.where .. " | " .. e.desc)
    end

    local function find(keys, where)
        for _, e in ipairs(s.nvim_keys()) do
            if e.keys == keys and (where == nil or e.where == where) then
                return e
            end
        end
    end
    local function show(e)
        return e and (e.where .. " | " .. e.desc) or "missing"
    end
    put("nvim[<leader>ff]", show(find("<leader>ff")))
    put("nvim[<leader>p]", show(find("<leader>p")))
    put("nvim[grr LSP]", show(find("grr", "LSP")))
    put("nvim[]c Git]", show(find("]c", "Git")))
    put("nvim[<leader>rn LSP]", show(find("<leader>rn", "LSP")))
    local ff = find("<leader>ff")
    put("nvim[<leader>ff].from", ff and ff.from)
    local yc = find("<leader>yc")
    put("nvim[<leader>yc].from", yc and yc.from and (yc.from:gsub(":%d+$", "")))
    local esc = find("<Esc>")
    put("nvim[<Esc>].runs", esc and esc.runs)
    return table.concat(out, "\n")
end
