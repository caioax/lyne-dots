-- tmux's sessions and project folders in one Telescope list (tmux's
-- prefix + P): a session switches to it; a folder switches to the session
-- named after it, starting one there first when there's none. The folders
-- are the ones inside each root ($LYNE_PROJECT_ROOTS, colon separated, or
-- ~/Dev) and lyne-dots itself

local M = {}

local function tmux(args)
    local result = vim.system(vim.list_extend({ "tmux" }, args), { text = true }):wait()
    return result.code == 0 and result.stdout or nil
end

function M.roots()
    local env = vim.env.LYNE_PROJECT_ROOTS
    if env and env ~= "" then
        return vim.split(env, ":", { trimempty = true })
    end
    return { vim.fn.expand("~/Dev") }
end

-- A folder's session name: its name without leading dots, "." and ":"
-- (tmux's separators) turned into "_"
function M.session_name(dir)
    local name = vim.fn.fnamemodify(vim.fs.normalize(dir), ":t"):gsub("^%.+", ""):gsub("[.:]", "_")
    return name ~= "" and name or "project"
end

-- tmux's sessions but the scratch terminal's (prefix + S)
function M.sessions()
    local out = {}
    local text =
        tmux({ "list-sessions", "-F", "#{session_name}\t#{session_path}\t#{session_windows}\t#{session_attached}" })
    for line in (text or ""):gmatch("[^\n]+") do
        local name, path, windows, attached = line:match("^([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)$")
        if name and name ~= "scratch" then
            table.insert(out, { name = name, path = path, windows = tonumber(windows), attached = attached ~= "0" })
        end
    end
    return out
end

function M.folders()
    local out = {}
    for _, root in ipairs(M.roots()) do
        root = vim.fs.normalize(root)
        local names = {}
        for name, kind in vim.fs.dir(root) do
            if kind == "directory" and not name:match("^%.") then
                table.insert(names, name)
            end
        end
        table.sort(names, function(a, b)
            return a:lower() < b:lower()
        end)
        for _, name in ipairs(names) do
            table.insert(out, root .. "/" .. name)
        end
    end
    local dots = vim.fs.normalize(vim.env.LYNE_DOTS or "~/.lyne-dots")
    if vim.fn.isdirectory(dots) == 1 and not vim.tbl_contains(out, dots) then
        table.insert(out, dots)
    end
    return out
end

-- Open sessions first, then the folders without one
function M.entries()
    local out, open = {}, {}
    for _, s in ipairs(M.sessions()) do
        open[s.name] = true
        local detail = s.windows .. (s.windows == 1 and " window" or " windows") .. (s.attached and ", attached" or "")
        table.insert(out, { kind = "session", name = s.name, path = s.path, detail = detail })
    end
    for _, dir in ipairs(M.folders()) do
        local name = M.session_name(dir)
        if not open[name] then
            table.insert(out, { kind = "folder", name = name, path = dir, detail = "new session" })
        end
    end
    return out
end

-- Switches this tmux client (the popup's) to the entry's session
function M.open(entry)
    if not tmux({ "has-session", "-t", "=" .. entry.name }) then
        tmux({ "new-session", "-d", "-s", entry.name, "-c", entry.path })
    end
    tmux({ "switch-client", "-t", "=" .. entry.name })
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
    if not vim.env.TMUX then
        vim.notify("Projects: tmux's sessions, only inside tmux", vim.log.levels.WARN)
        return
    end

    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")
    local conf = require("telescope.config").values
    local entry_display = require("telescope.pickers.entry_display")

    local home = vim.fn.expand("~")
    local displayer = entry_display.create({
        separator = "  ",
        items = { { width = 7 }, { width = 24 }, { remaining = true } },
    })

    pickers
        .new({}, {
            prompt_title = "Projects and sessions",
            finder = finders.new_table({
                results = M.entries(),
                entry_maker = function(e)
                    local path = e.path:gsub("^" .. vim.pesc(home), "~")
                    return {
                        value = e,
                        ordinal = e.name .. " " .. path,
                        display = function()
                            return displayer({
                                { e.kind, e.kind == "session" and "Function" or "Comment" },
                                { e.name, "Special" },
                                { path .. "  · " .. e.detail, "Normal" },
                            })
                        end,
                    }
                end,
            }),
            sorter = conf.generic_sorter({}),
            attach_mappings = function(prompt_bufnr, map)
                actions.select_default:replace(function()
                    -- Before closing: in the popup, closing quits Neovim
                    local selected = action_state.get_selected_entry()
                    if selected then
                        M.open(selected.value)
                    end
                    actions.close(prompt_bufnr)
                end)
                -- Escape goes to normal mode (j / k move, Enter picks); a
                -- second Escape, or q, closes the list
                map("n", "q", actions.close)
                if opts.quit then
                    require("config.popup").quit_on_close(actions)
                end
                return true
            end,
        })
        :find()
end

return M
