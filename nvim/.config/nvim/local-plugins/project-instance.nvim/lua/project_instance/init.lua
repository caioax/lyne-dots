-- One Neovim per project. The first Neovim opened in a project listens on a
-- socket named after the project's folder ($XDG_RUNTIME_DIR/lyne-nvim/), so
-- whoever wants to open a file of that project (another Neovim, lyne nvim
-- open, Godot) finds it there. The folder comes from the first file given
-- (or the current one): the nearest folder upwards holding project.godot, a
-- *.sln or .git, else the file's own folder.
--
-- Neovims that never take a project's socket (state.skipped says why):
--   solo      LYNE_NVIM_SOLO=1 (tmux's popups set it)
--   headless  no UI (scripts, Mason, tests); LYNE_NVIM_INSTANCE=1 overrides
--   flag      -R, -d, -M, -e, -E, -es, -Es, or - (text from stdin)
--   waiting   a file someone waits for Neovim to finish: git's (commit
--             message, rebase todo, anything in .git/) or a temp file
--             (zsh's edit-command-line, crontab -e, sudoedit)

local M = {}

-- What this Neovim is: root, socket, pane ($TMUX_PANE), tmux ($TMUX), owner
-- (it listens on the socket) or other (a live Neovim already does), or
-- skipped (the reason)
M.state = {}

local uv = vim.uv

local skip_flags = {
    ["-R"] = true,
    ["-d"] = true,
    ["-M"] = true,
    ["-e"] = true,
    ["-E"] = true,
    ["-es"] = true,
    ["-Es"] = true,
    ["-"] = true,
}

local git_files = {
    COMMIT_EDITMSG = true,
    MERGE_MSG = true,
    SQUASH_MSG = true,
    TAG_EDITMSG = true,
    EDIT_DESCRIPTION = true,
    ["git-rebase-todo"] = true,
    ["addp-hunk-edit.diff"] = true,
}

local function absolute(path)
    return vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
end

-- A file someone is waiting on: git's or a temp file
function M.is_waiting_file(path)
    path = absolute(path)
    if git_files[vim.fs.basename(path)] or path:find("/%.git/") then
        return true
    end
    -- Programs write their temp files to $TMPDIR, /tmp without it
    local tmp = vim.env.TMPDIR
    for _, dir in ipairs({ (tmp and tmp ~= "") and tmp or "/tmp", "/var/tmp" }) do
        dir = vim.fs.normalize(dir)
        if path:sub(1, #dir + 1) == dir .. "/" then
            return true
        end
    end
    return false
end

-- Why this Neovim is not a project's, or nil
function M.skip_reason()
    if vim.env.LYNE_NVIM_SOLO == "1" then
        return "solo"
    end
    if #vim.api.nvim_list_uis() == 0 and vim.env.LYNE_NVIM_INSTANCE ~= "1" then
        return "headless"
    end
    for i = 2, #vim.v.argv do
        local arg = vim.v.argv[i]
        if arg == "--" then
            break
        end
        if skip_flags[arg] then
            return "flag"
        end
    end
    for _, file in ipairs(vim.fn.argv()) do
        if M.is_waiting_file(file) then
            return "waiting"
        end
    end
    return nil
end

local function has_marker(dir)
    if uv.fs_stat(dir .. "/project.godot") or uv.fs_stat(dir .. "/.git") then
        return true
    end
    local ok, iter = pcall(vim.fs.dir, dir)
    if ok then
        for name in iter do
            if name:match("%.sln$") then
                return true
            end
        end
    end
    return false
end

-- The project folder of PATH (a file, which may not exist yet, or a folder;
-- the current folder when nil)
function M.root(path)
    path = absolute(path or vim.fn.getcwd())
    local start = vim.fn.isdirectory(path) == 1 and path or vim.fs.dirname(path)
    -- A new file in a folder that doesn't exist yet: from its nearest parent
    while vim.fn.isdirectory(start) == 0 and start ~= "/" do
        start = vim.fs.dirname(start)
    end
    if has_marker(start) then
        return start
    end
    for dir in vim.fs.parents(start) do
        if has_marker(dir) then
            return dir
        end
    end
    return start
end

-- A folder's tmux session name, the same as config/projects.lua's: its name
-- without leading dots, "." and ":" (tmux's separators) turned into "_"
function M.session_name(dir)
    local name = vim.fn.fnamemodify(vim.fs.normalize(dir), ":t"):gsub("^%.+", ""):gsub("[.:]", "_")
    return name ~= "" and name or "project"
end

-- The socket of the project at ROOT: the session name plus a short hash of
-- the path (two folders with the same name get their own)
function M.socket(root)
    local base = vim.env.XDG_RUNTIME_DIR
    if not base or base == "" then
        base = vim.fn.stdpath("run")
    end
    return base .. "/lyne-nvim/" .. M.session_name(root) .. "-" .. vim.fn.sha256(root):sub(1, 8) .. ".sock"
end

-- A Neovim answers on SOCKET (a file left by one that was killed doesn't)
function M.alive(socket)
    if not uv.fs_stat(socket) then
        return false
    end
    local ok, chan = pcall(vim.fn.sockconnect, "pipe", socket, { rpc = true })
    if not ok or chan == 0 then
        return false
    end
    vim.fn.chanclose(chan)
    return true
end

-- For whoever reaches this Neovim on its socket
function M.info()
    return vim.tbl_extend("force", vim.deepcopy(M.state), { pid = vim.fn.getpid() })
end

function M.setup()
    vim.api.nvim_create_user_command("ProjectInstance", function()
        vim.print(M.info())
    end, { desc = "Show this Neovim's project, socket and tmux pane" })

    local reason = M.skip_reason()
    if reason then
        M.state = { skipped = reason }
        return
    end
    local first = vim.fn.argv(0)
    local root = M.root(first ~= "" and first or nil)
    local socket = M.socket(root)
    M.state = { root = root, socket = socket, pane = vim.env.TMUX_PANE, tmux = vim.env.TMUX }
    if M.alive(socket) then
        M.state.owner, M.state.other = false, true
        return
    end
    vim.fn.mkdir(vim.fs.dirname(socket), "p", tonumber("700", 8))
    if uv.fs_stat(socket) then
        os.remove(socket)
    end
    -- Two Neovims starting at once: the second one finds it taken
    M.state.owner = pcall(vim.fn.serverstart, socket)
    if not M.state.owner then
        M.state.other = true
    end
end

return M
