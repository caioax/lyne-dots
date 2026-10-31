# lyne nvim - Open files in the project's Neovim, inside tmux

local plugin="$DOTS_DIR/nvim/.config/nvim/local-plugins/project-instance.nvim"
local cli="$plugin/lua/project_instance/cli.lua"
local default_apps="$DOTS_DIR/quickshell/.config/quickshell/scripts/default-apps.sh"
# Seconds to wait for a Neovim to come up, and for tmux-continuum's restore
local wait_nvim="${LYNE_NVIM_WAIT:-15}" wait_restore="${LYNE_NVIM_RESTORE_WAIT:-20}"

_nvim_usage() {
    echo "Usage: lyne nvim open [--project <folder>] <file> [line [column]]"
    echo "       lyne nvim list"
    echo ""
    echo "One Neovim per project (Neovim's local-plugins/project-instance.nvim)."
    echo ""
    echo "Subcommands:"
    echo "  open    Opens the file in its project's Neovim at the line and column,"
    echo "          and shows it: tmux switches to its pane and Hyprland focuses the"
    echo "          terminal. Without one, Neovim starts in a new window of the"
    echo "          project's tmux session (made in the project folder when there's"
    echo "          none; when tmux isn't running, after tmux-continuum brings back"
    echo "          the last save), and a terminal opens when none shows tmux."
    echo "          The project is --project, else the nearest folder of the file"
    echo "          with project.godot, a *.sln or .git. A line below 1 means none."
    echo "          For Godot (Editor Settings > Dotnet > Editor, Custom):"
    echo "            exec path  lyne"
    echo "            arguments  nvim open --project {project} {file} {line} {col}"
    echo "  list    The project Neovims running: folder, tmux pane, pid and socket"
}

# Errors also as a notification: Godot runs this with no terminal to show them
_nvim_fail() {
    echo "lyne nvim: $1" >&2
    notify-send -a "Neovim" -i nvim "Couldn't open in Neovim" "$1" 2>/dev/null
    return 1
}

_nvim_cli() { nvim --clean --headless -l "$cli" "$@"; }

# A word for a shell command line, single quoted
_nvim_quote() { printf "'%s'" "${1//\'/\'\\\'\'}"; }

# Hyprland focuses the window of PID or its nearest parent that has one
_nvim_focus_window() {
    local pid="$1" pids
    [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" && -n "$pid" ]] || return 0
    pids=" $(hyprctl clients -j 2>/dev/null | jq -r '[.[].pid] | join(" ")' 2>/dev/null) "
    while [[ -n "$pid" && "$pid" -gt 1 ]]; do
        if [[ "$pids" == *" $pid "* ]]; then
            hyprctl dispatch "hl.dsp.focus({ window = \"pid:$pid\" })" >/dev/null 2>&1
            return 0
        fi
        pid="$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')"
    done
}

# Shows PANE of the tmux server at SOCKET: the client used last switches to
# it and its terminal gets the focus; with no client, a terminal attaches
_nvim_show_pane() {
    local pane="$1" socket="$2" client client_pid session
    local t=(tmux -S "$socket")
    read -r _ client client_pid < <("${t[@]}" list-clients -F '#{client_activity} #{client_name} #{client_pid}' 2>/dev/null | sort -rn | head -1)
    if [[ -n "$client" ]]; then
        "${t[@]}" switch-client -c "$client" -t "$pane"
        _nvim_focus_window "$client_pid"
        return 0
    fi
    session="$("${t[@]}" display -p -t "$pane" '#{session_name}')"
    "${t[@]}" select-window -t "$pane" \; select-pane -t "$pane"
    [[ -x "$default_apps" ]] || return 0
    setsid -f "$default_apps" term tmux -S "$socket" attach-session -t "=$session" </dev/null >/dev/null 2>&1
}

# Sends FILE LINE COL to the Neovim on SOCKET and shows it
_nvim_send() {
    local socket="$1" pane tmux_env pid
    shift
    IFS=$'\t' read -r pane tmux_env pid < <(_nvim_cli send "$socket" "$@") || return 1
    [[ -n "$pid" ]] || return 1
    if [[ -n "$pane" && -n "$tmux_env" ]]; then
        _nvim_show_pane "$pane" "${tmux_env%%,*}"
    else
        # Not in tmux: its terminal, at least
        _nvim_focus_window "$pid"
    fi
}

# Waits while tmux-continuum's restore (and the resurrect restore it runs)
# is going
_nvim_wait_restore() {
    local tries=$((wait_restore * 5))
    sleep 0.3
    while pgrep -u "$(id -u)" -f 'tmux-(continuum|resurrect)/scripts/(continuum_)?restore\.sh' >/dev/null && ((tries-- > 0)); do
        sleep 0.2
    done
}

_nvim_open() {
    local project="" file="" line="" col=""
    while (($#)); do
        case "$1" in
            --project)
                project="${2:-}"
                shift 2 || { _nvim_usage >&2; return 1; }
                ;;
            -[0-9]* | [0-9]* | "" | [!-]*)
                # Godot gives -1 for no line
                if [[ -z "$file" ]]; then file="$1"
                elif [[ -z "$line" ]]; then line="$1"
                else col="$1"
                fi
                shift
                ;;
            *)
                _nvim_usage >&2
                return 1
                ;;
        esac
    done
    [[ -n "$file" ]] || { _nvim_usage >&2; return 1; }
    command -v nvim >/dev/null || { _nvim_fail "nvim isn't installed (sudo pacman -S neovim)"; return 1; }
    command -v tmux >/dev/null || { _nvim_fail "tmux isn't installed (sudo pacman -S tmux)"; return 1; }
    file="$(realpath -m -- "$file")"

    local root session socket alive
    local locate=(locate)
    [[ -n "$project" ]] && locate+=(--project "$project")
    locate+=("$file")
    IFS=$'\t' read -r root session socket alive < <(_nvim_cli "${locate[@]}")
    [[ -n "$socket" ]] || { _nvim_fail "the project of $file wasn't found"; return 1; }

    if [[ "$alive" == 1 ]]; then
        _nvim_send "$socket" "$file" "$line" "$col" && return 0
    fi

    # No Neovim there: tmux first. A tmux started now brings back its last
    # save (tmux-continuum), maybe with this project's Neovim in it
    local created=0
    if ! tmux list-sessions >/dev/null 2>&1; then
        tmux new-session -d -s "$session" -c "$root" || { _nvim_fail "tmux didn't start"; return 1; }
        created=1
        _nvim_wait_restore
        IFS=$'\t' read -r _ _ _ alive < <(_nvim_cli "${locate[@]}")
        if [[ "$alive" == 1 ]]; then
            _nvim_send "$socket" "$file" "$line" "$col" && return 0
        fi
    fi
    if ! tmux has-session -t "=$session" 2>/dev/null; then
        tmux new-session -d -s "$session" -c "$root" || { _nvim_fail "the tmux session $session wasn't made"; return 1; }
        created=1
    fi

    # Neovim in the session's only pane when it was just made (its shell),
    # else in a new window. Typed into the shell, which runs it in the
    # foreground (tmux names the window after it, resurrect sees it) and
    # takes over when it quits
    local pane="" panes
    if [[ $created == 1 ]]; then
        panes="$(tmux list-panes -s -t "=$session" -F '#{pane_id}')"
        [[ "$(wc -l <<<"$panes")" == 1 ]] && pane="$panes"
    fi
    [[ -n "$pane" ]] || pane="$(tmux new-window -P -F '#{pane_id}' -t "=$session:" -c "$root")"
    [[ -n "$pane" ]] || { _nvim_fail "no tmux window for Neovim"; return 1; }
    tmux send-keys -t "$pane" -l "nvim -- $(_nvim_quote "$file")" \; send-keys -t "$pane" Enter

    local tries=$((wait_nvim * 5))
    while ((tries-- > 0)); do
        IFS=$'\t' read -r _ _ _ alive < <(_nvim_cli "${locate[@]}")
        [[ "$alive" == 1 ]] && break
        sleep 0.2
    done
    [[ "$alive" == 1 ]] || { _nvim_fail "Neovim didn't start in the tmux session $session"; return 1; }
    _nvim_send "$socket" "$file" "$line" "$col" || { _nvim_fail "Neovim didn't answer"; return 1; }
}

case "${1:-}" in
    -h|--help|"")
        _nvim_usage
        ;;
    open)
        shift
        _nvim_open "$@"
        ;;
    list)
        local root pane pid socket
        while IFS=$'\t' read -r root pane pid socket; do
            printf '%s\t%s\t%s\t%s\n' "${root/#$HOME/\~}" "${pane:--}" "$pid" "${socket/#$HOME/\~}"
        done < <(_nvim_cli list)
        ;;
    *)
        _nvim_usage >&2
        return 1
        ;;
esac
