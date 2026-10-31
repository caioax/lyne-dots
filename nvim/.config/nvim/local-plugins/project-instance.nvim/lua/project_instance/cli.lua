-- The plugin for scripts (lyne nvim), run without the config:
--   nvim --clean --headless -l .../project_instance/cli.lua <command> ...
--
--   locate [--project DIR] [FILE]
--       root, session name, socket and 1/0 (a live Neovim on it), tab
--       separated: the project of DIR, else FILE's (else the current folder)
--   send SOCKET [FILE [LINE [COL]]]
--       opens FILE in the Neovim on SOCKET (just brings it up without one);
--       prints its tmux pane, $TMUX and pid, tab separated. Exit 1 when
--       nothing answers there
--   list
--       the live Neovims: root, pane, pid and socket, tab separated

local here = debug.getinfo(1, "S").source:sub(2)
-- lua/project_instance/cli.lua -> the plugin's folder
vim.opt.rtp:prepend(vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(here))))
local pi = require("project_instance")

local args = _G.arg or {}

local function out(...)
    io.stdout:write(table.concat({ ... }, "\t"), "\n")
end

local function fail(message)
    io.stderr:write("project-instance: ", message, "\n")
    os.exit(1)
end

-- The info() of the Neovim on SOCKET after open(FILES, POS), or nil
local function request(socket, files, pos)
    local ok, chan = pcall(vim.fn.sockconnect, "pipe", socket, { rpc = true })
    if not ok or chan == 0 then
        return nil
    end
    local sent, info =
        pcall(vim.rpcrequest, chan, "nvim_exec_lua", "return require('project_instance').open(...)", { files, pos })
    vim.fn.chanclose(chan)
    return sent and type(info) == "table" and info or nil
end

local command = args[1]
if command == "locate" then
    local project, file
    local i = 2
    while i <= #args do
        if args[i] == "--project" then
            project = args[i + 1]
            i = i + 2
        else
            file = args[i]
            i = i + 1
        end
    end
    local root = project and vim.fs.normalize(vim.fn.fnamemodify(project, ":p")) or pi.root(file)
    local socket = pi.socket(root)
    out(root, pi.session_name(root), socket, pi.alive(socket) and "1" or "0")
elseif command == "send" then
    local socket, file, line, col = args[2], args[3], tonumber(args[4] or ""), tonumber(args[5] or "")
    if not socket then
        fail("send SOCKET [FILE [LINE [COL]]]")
    end
    local files = {}
    if file and file ~= "" then
        files = { vim.fs.normalize(vim.fn.fnamemodify(file, ":p")) }
    end
    -- Godot gives -1 or 0 when there's no line
    local pos = (line and line > 0) and { line = line, col = (col and col > 0) and col or nil } or nil
    local info = request(socket, files, pos)
    if not info then
        fail("no Neovim answers on " .. socket)
    end
    out(info.pane or "", info.tmux or "", tostring(info.pid or ""))
elseif command == "list" then
    local base = vim.fs.dirname(pi.socket("/"))
    for name, kind in vim.fs.dir(base) do
        local socket = base .. "/" .. name
        if kind == "socket" and pi.alive(socket) then
            local ok, chan = pcall(vim.fn.sockconnect, "pipe", socket, { rpc = true })
            if ok and chan > 0 then
                local got, info =
                    pcall(vim.rpcrequest, chan, "nvim_exec_lua", "return require('project_instance').info()", {})
                vim.fn.chanclose(chan)
                if got and type(info) == "table" then
                    out(info.root or "", info.pane or "", tostring(info.pid or ""), socket)
                end
            end
        end
    end
else
    fail("unknown command: " .. tostring(command) .. " (locate, send, list)")
end
