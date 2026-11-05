-- tmux's sessions and project folders in one Telescope list (tmux's
-- prefix + P): a session switches to it; a folder switches to the session
-- named after it, starting one there first when there's none. The folders
-- come from each root ($LYNE_PROJECT_ROOTS, colon separated, or ~/Dev): a
-- folder in it that is a project (project_instance's markers) is listed; one
-- that isn't lists the projects inside it instead, down to three levels
-- below the root (~/Dev/Python gives ~/Dev/Python/game), or itself when it
-- has none. Inside a project only a .root makes another one (a repo's
-- submodules and vendored repos stay out), within the same three levels.
-- lyne-dots itself is always there.
--
-- dd (Ctrl+d while typing) on an entry: a session closes (after a y/n), a
-- folder is hidden from the list (saved in Neovim's state folder); H (Ctrl+h)
-- shows the hidden ones too, where dd brings one back

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

-- Folders a project can't be in
local skip_dirs = { node_modules = true }

-- DIR's subfolders, not hidden ones, sorted by name ignoring case
local function subdirs(dir)
    local names = {}
    local ok, iter = pcall(vim.fs.dir, dir)
    for name, kind in ok and iter or function() end do
        if kind == "directory" and not name:match("^%.") and not skip_dirs[name] then
            table.insert(names, name)
        end
    end
    table.sort(names, function(a, b)
        return a:lower() < b:lower()
    end)
    return vim.tbl_map(function(name)
        return dir .. "/" .. name
    end, names)
end

-- The folders with a .root inside the project DIR, DEPTH levels down at most
local function marked_in(dir, depth, out)
    if depth < 1 then
        return out
    end
    for _, sub in ipairs(subdirs(dir)) do
        if vim.uv.fs_stat(sub .. "/.root") then
            table.insert(out, sub)
        end
        marked_in(sub, depth - 1, out)
    end
    return out
end

-- The projects inside DIR, DEPTH levels down at most; in a project's own
-- subfolders, only the ones with a .root
local function projects_in(dir, depth, out)
    for _, sub in ipairs(subdirs(dir)) do
        if require("project_instance").has_marker(sub) then
            table.insert(out, sub)
            marked_in(sub, depth - 1, out)
        elseif depth > 1 then
            projects_in(sub, depth - 1, out)
        end
    end
    return out
end

function M.folders()
    local out = {}
    local has_marker = require("project_instance").has_marker
    for _, root in ipairs(M.roots()) do
        for _, dir in ipairs(subdirs(vim.fs.normalize(root))) do
            if has_marker(dir) then
                table.insert(out, dir)
                marked_in(dir, 2, out)
            else
                local inside = projects_in(dir, 2, {})
                vim.list_extend(out, #inside > 0 and inside or { dir })
            end
        end
    end
    local dots = vim.fs.normalize(vim.env.LYNE_DOTS or "~/.lyne-dots")
    if vim.fn.isdirectory(dots) == 1 and not vim.tbl_contains(out, dots) then
        table.insert(out, dots)
    end
    return out
end

-- The folders hidden from the list: a JSON list of paths
local function hidden_file()
    return vim.fn.stdpath("state") .. "/lyne-projects-hidden.json"
end

-- The hidden folders, as a set of paths
function M.hidden()
    local ok, list = pcall(function()
        return vim.json.decode(table.concat(vim.fn.readfile(hidden_file()), "\n"))
    end)
    local set = {}
    for _, dir in ipairs(ok and type(list) == "table" and list or {}) do
        set[dir] = true
    end
    return set
end

-- Hides DIR from the list, or brings it back (hide false)
function M.set_hidden(dir, hide)
    local set = M.hidden()
    set[dir] = hide or nil
    local list = vim.tbl_keys(set)
    table.sort(list)
    vim.fn.mkdir(vim.fn.stdpath("state"), "p")
    vim.fn.writefile({ vim.json.encode(list) }, hidden_file())
end

-- Open sessions first, then the folders without one; the hidden folders
-- left out, or listed last with opts.hidden
function M.entries(opts)
    opts = opts or {}
    local out, open, later = {}, {}, {}
    local hidden = M.hidden()
    for _, s in ipairs(M.sessions()) do
        open[s.name] = true
        local detail = s.windows .. (s.windows == 1 and " window" or " windows") .. (s.attached and ", attached" or "")
        table.insert(out, { kind = "session", name = s.name, path = s.path, detail = detail })
    end
    for _, dir in ipairs(M.folders()) do
        local name = M.session_name(dir)
        if open[name] then
            -- listed as its session
        elseif not hidden[dir] then
            table.insert(out, { kind = "folder", name = name, path = dir, detail = "new session" })
        elseif opts.hidden then
            table.insert(later, { kind = "hidden", name = name, path = dir, detail = "hidden, dd shows it again" })
        end
    end
    return vim.list_extend(out, later)
end

-- dd on ENTRY: a session closes once you say yes, a folder is hidden, a
-- hidden one comes back. True when the list changed
function M.remove(entry)
    if entry.kind == "session" then
        local answer = vim.fn.confirm(
            "Close the session " .. entry.name .. "? Its windows and what runs in them end.",
            "&Yes\n&No",
            2
        )
        return answer == 1 and tmux({ "kill-session", "-t", "=" .. entry.name }) ~= nil
    end
    M.set_hidden(entry.path, entry.kind == "folder")
    return true
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
    local show_hidden = false
    local displayer = entry_display.create({
        separator = "  ",
        items = { { width = 7 }, { width = 24 }, { remaining = true } },
    })

    local function make_finder()
        return finders.new_table({
            results = M.entries({ hidden = show_hidden }),
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
        })
    end

    pickers
        .new({}, {
            prompt_title = "Projects and sessions",
            finder = make_finder(),
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
                -- The list again, keeping what was typed
                local function refresh()
                    local picker = action_state.get_current_picker(prompt_bufnr)
                    picker:refresh(make_finder(), { reset_prompt = false })
                end
                local function remove()
                    local selected = action_state.get_selected_entry()
                    if selected and M.remove(selected.value) then
                        refresh()
                    end
                end
                local function toggle_hidden()
                    show_hidden = not show_hidden
                    refresh()
                end
                map("n", "dd", remove)
                map("i", "<C-d>", remove)
                map("n", "H", toggle_hidden)
                map("i", "<C-h>", toggle_hidden)
                if opts.quit then
                    require("config.popup").quit_on_close(actions)
                end
                return true
            end,
        })
        :find()
end

return M
