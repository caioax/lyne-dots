#!/usr/bin/env bash
# =============================================================================
# smoke.sh - The whole shell, started and clicked through in a sandbox
# =============================================================================
# Starts a nested Hyprland inside the running session (a hidden special
# workspace, opened silently: nothing shows and focus stays where it is),
# runs the real shell.qml in it with a throwaway HOME, its own runtime dir
# and session bus, then opens every window, Settings page, dashboard tab,
# Quick Settings page and launcher mode, shows the OSD and a notification,
# locks and unlocks, switches themes; all of it in pt_BR, then the language
# switched live (en, pt_BR, en). The nested Hyprland loads the repo's
# special workspaces too (an app opens only when one is shown empty). It fails on any QML error or warning
# the shell logs (tests/qml/allowed.txt lists the expected ones, from the
# sandbox itself) and when anything outside the sandbox changed.
#
# Isolation: the nested Hyprland and the shell only see $SB/run, so hyprctl
# and Quickshell's Hyprland module reach the nested compositor, never yours.
# Commands with effects outside it (nmcli, rfkill, brightness, systemctl,
# systemd-inhibit, pkill, kitty, nvim, zenity...) are stand-ins that log to
# $SB/calls.log. Battery rules, update checks and idle are off in its state.
# The nested Hyprland is stopped with kill, never a dispatch.
#
# Usage: tests/qml/smoke.sh   (in a Hyprland session)
#   SMOKE_KEEP=1   keep the sandbox (its path is printed) for a look
#   SMOKE_WAIT=s   wait after each step (default 0.6)
#   SMOKE_SHELL / SMOKE_SPECIALS / SMOKE_WORKSPACES
#                  copies to run instead (a test that they fail)
# =============================================================================

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# SMOKE_SHELL: another copy of the shell config (a test that it fails)
SHELL_DIR="${SMOKE_SHELL:-$REPO/quickshell/.config/quickshell}"
# SMOKE_SPECIALS / SMOKE_WORKSPACES: other copies of conf/specials.lua and
# conf/workspaces.lua (a test that they fail)
SPECIALS="${SMOKE_SPECIALS:-$REPO/hyprland/.config/hypr/conf/specials.lua}"
WORKSPACES="${SMOKE_WORKSPACES:-$REPO/hyprland/.config/hypr/conf/workspaces.lua}"
ALLOWED="$REPO/tests/qml/allowed.txt"
WAIT="${SMOKE_WAIT:-0.6}"

if [[ -t 1 ]]; then
    C_OK=$'\e[32m' C_FAIL=$'\e[31m' C_DIM=$'\e[2m' C_OFF=$'\e[0m'
else
    C_OK="" C_FAIL="" C_DIM="" C_OFF=""
fi

fail_early() {
    echo "${C_FAIL}smoke: $1${C_OFF}" >&2
    exit 1
}

# -----------------------------------------------------------------------------
# Preflight: a Hyprland session to nest into, and the tools
# -----------------------------------------------------------------------------
for tool in Hyprland qs jq dbus-run-session python3; do
    command -v "$tool" >/dev/null || fail_early "$tool not found"
done
if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" || -z "${WAYLAND_DISPLAY:-}" ]] || ! hyprctl version >/dev/null 2>&1; then
    fail_early "needs a running Hyprland session (it nests one inside it)"
fi
LIVE_WL="$WAYLAND_DISPLAY"
[[ "$LIVE_WL" == /* ]] || LIVE_WL="$XDG_RUNTIME_DIR/$LIVE_WL"

LIVE_STATE="$HOME/.config/quickshell/state.json"
live_state_sum="$(sha1sum "$LIVE_STATE" 2>/dev/null)"
LIVE_WS_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/lyne/workspace-monitors.lua"
live_ws_state_sum="$(sha1sum "$LIVE_WS_STATE" 2>/dev/null)"
repo_status="$(git -C "$REPO" status --porcelain)"

# Short path: the Hyprland sockets under it must stay below 108 characters
SB="$(mktemp -d /tmp/lq.XXXXXX)" || fail_early "no sandbox"

# Every process whose environment holds our runtime dir: the nested
# Hyprland, the shell, its bus and whatever the bus started
sandbox_pids() {
    local e p
    for e in /proc/[0-9]*/environ; do
        p=${e#/proc/}
        p=${p%/environ}
        [[ "$p" == "$$" || "$p" == "$BASHPID" ]] && continue
        { tr '\0' '\n' <"$e"; } 2>/dev/null | grep -qxF "XDG_RUNTIME_DIR=$SB/run" && echo "$p"
    done
}

cleanup() {
    local pids p
    mapfile -t pids < <(sandbox_pids)
    ((${#pids[@]})) && kill "${pids[@]}" 2>/dev/null
    for _ in {1..20}; do
        mapfile -t pids < <(sandbox_pids)
        ((${#pids[@]})) || break
        sleep 0.1
    done
    for p in "${pids[@]}"; do kill -9 "$p" 2>/dev/null; done
    if [[ -n "${SMOKE_KEEP:-}" ]]; then
        echo "${C_DIM}sandbox kept: $SB${C_OFF}"
    else
        rm -rf "$SB"
    fi
}
trap cleanup EXIT
trap 'exit 130' INT TERM

# -----------------------------------------------------------------------------
# The sandbox: config, HOME, stand-ins
# -----------------------------------------------------------------------------
build_sandbox() {
    local item cfg="$SB/cfg" home="$SB/home"
    mkdir -p "$SB/run" "$SB/bin" "$cfg/scripts" "$home/.config" "$home/.local/themes" \
        "$home/.lyne-dots/quickshell/.config" "$home/.lyne-dots/.data" "$home/Pictures"
    chmod 700 "$SB/run"

    # The shell as it is, except: its own state.json, a stand-in for the
    # Bluetooth agent (the real one registers on the system bus), and an
    # IpcHandler to drive it
    for item in "$SHELL_DIR"/*; do
        case "${item##*/}" in
        state.json | shell.qml | scripts) ;;
        *) ln -s "$item" "$cfg/" ;;
        esac
    done
    for item in "$SHELL_DIR"/scripts/*; do
        [[ "${item##*/}" == bluetooth-agent.py ]] || ln -s "$item" "$cfg/scripts/"
    done
    printf 'import time\nwhile True:\n    time.sleep(60)\n' >"$cfg/scripts/bluetooth-agent.py"
    python3 - "$SHELL_DIR/shell.qml" "$cfg/shell.qml" <<'EOF'
import sys
text = open(sys.argv[1]).read()
end = text.rstrip().rfind("}")
probe = """
    // Added by tests/qml/smoke.sh
    IpcHandler {
        target: "smoke"
        function ev(js: string): string {
            try {
                return String(eval(js));
            } catch (e) {
                return "ERROR " + e;
            }
        }
    }
"""
open(sys.argv[2], "w").write(text[:end] + probe + text[end:])
EOF
    jq '.powerProfiles.lowBattery = false | .powerProfiles.onUnplug = false
        | .update.notify = false | .idle.lockTimeout = 0 | .idle.dpmsTimeout = 0
        | .general.language = "pt_BR"' \
        "$REPO/.data/quickshell/defaults.json" >"$cfg/state.json"

    # HOME as an install leaves it: the config linked, themes and their
    # wallpapers copied, ~/.lyne-dots seen through links (no .git: nothing
    # may write into the repo's)
    ln -s "$cfg" "$home/.config/quickshell"
    for item in "$REPO"/* "$REPO"/.[!.]*; do
        case "${item##*/}" in
        .git | .data | quickshell) ;;
        *) ln -s "$item" "$home/.lyne-dots/" ;;
        esac
    done
    for item in "$REPO"/.data/*; do ln -s "$item" "$home/.lyne-dots/.data/"; done
    ln -s "$cfg" "$home/.lyne-dots/quickshell/.config/quickshell"
    cp "$REPO"/.data/themes/*.json "$home/.local/themes/"
    # What stow links on an install and the shell writes to: copies here
    local pkg
    # (a fresh clone has no kde/: its only file is kept out of git)
    for pkg in theming kde kitty; do
        [[ -d "$REPO/$pkg/.config" ]] && cp -r "$REPO/$pkg/.config/." "$home/.config/"
    done
    # The config files each machine keeps for itself (out of git) as a new
    # install makes them: from the repo's defaults, not this machine's
    for pkg in theming kde; do cp -r "$REPO/.data/config-defaults/$pkg/.config/." "$home/.config/"; done
    # The default icon theme, whether or not this machine has it: Tela-blue
    # and its variants as index.theme only (icons come from breeze)
    local tela
    for tela in Tela-blue Tela-blue-dark Tela-blue-light; do
        mkdir -p "$home/.local/share/icons/$tela"
        printf '[Icon Theme]\nName=%s\nInherits=breeze,hicolor\nDirectories=48/apps\n\n[48/apps]\nSize=48\n' "$tela" \
            >"$home/.local/share/icons/$tela/index.theme"
    done
    mkdir -p "$home/.config/hypr/local"
    local dir theme
    for dir in "$REPO"/.data/wallpapers/themes/*/; do
        theme="$(basename "$dir")"
        mkdir -p "$home/.local/wallpapers/themes/$theme"
        cp "$dir"lyne-*-contour.jpg "$home/.local/wallpapers/themes/$theme/" 2>/dev/null
    done

    local t
    for t in nmcli rfkill brightnessctl ddcutil hyprsunset kitty nvim loginctl zenity \
        awww awww-daemon gsettings systemctl systemd-inhibit pkill killall xdg-open setsid \
        missioncenter kwriteconfig6 kbuildsycoca6 powerprofilesctl lyne-sddm grim slurp satty \
        wpctl pactl playerctl bluetoothctl cava dbus-send; do
        printf '#!/bin/bash\necho "%s $*" >>"%s/calls.log"\n' "$t" "$SB" >"$SB/bin/$t"
        chmod +x "$SB/bin/$t"
    done
    # tmux reaches your server through /tmp, not the sandbox: a stand-in
    # that answers where tmux-resurrect's save script is (the power menu
    # saves tmux before leaving the session)
    cat >"$SB/bin/tmux" <<EOF
#!/bin/bash
echo "tmux \$*" >>"$SB/calls.log"
[[ "\$1" == show-options && "\$*" == *@resurrect-save-script-path* ]] && echo "$SB/resurrect-save.sh"
exit 0
EOF
    chmod +x "$SB/bin/tmux"
    # nmcli: no network, until a step plugs in a cable ($SB/wired) and
    # raises a NetworkManager event ($SB/nm-event, read by `nmcli monitor`)
    cat >"$SB/bin/nmcli" <<EOF
#!/bin/bash
echo "nmcli \$*" >>"$SB/calls.log"
case "\$*" in
    monitor)
        while sleep 0.2; do
            [[ -e "$SB/nm-event" ]] && rm -f "$SB/nm-event" && echo "enp3s0: changed"
        done
        ;;
    "-g DEVICE,TYPE,STATE,CONNECTION device")
        [[ -e "$SB/wired" ]] && echo "enp3s0:ethernet:connected:Wired connection 1"
        echo "wlan0:wifi:disconnected:"
        ;;
    *CAPABILITIES.SPEED*)
        [[ -e "$SB/wired" ]] && printf '192.168.1.7/24\\n192.168.1.1\\n192.168.1.1\\n1000 Mb/s\\n'
        ;;
esac
exit 0
EOF
    chmod +x "$SB/bin/nmcli"
}

# cable on|off: plugs the stand-in cable in or out (an nmcli event follows)
cable() {
    if [[ "$1" == on ]]; then touch "$SB/wired"; else rm -f "$SB/wired"; fi
    touch "$SB/nm-event"
}

# saved_before_reboot: calls.log has resurrect's save before systemctl reboot
saved_before_reboot() {
    local save reboot
    save="$(grep -n "^tmux run-shell $SB/resurrect-save.sh quiet" "$SB/calls.log" | head -1 | cut -d: -f1)"
    reboot="$(grep -n "^systemctl reboot" "$SB/calls.log" | head -1 | cut -d: -f1)"
    [[ -n "$save" && -n "$reboot" && "$save" -lt "$reboot" ]]
}

# -----------------------------------------------------------------------------
# Nested Hyprland, then the shell inside it
# -----------------------------------------------------------------------------
start_nested() {
    cat >"$SB/hyprland.lua" <<'EOF'
hl.monitor({ output = "", mode = "1920x1080", position = "0x0", scale = 1 })
hl.config({ xwayland = { enabled = false }, animations = { enabled = false } })
EOF
    # The repo's workspaces per monitor (the lid always open) and special
    # workspaces, with apps that only leave a file
    echo "state:      open" >"$SB/lid-state"
    cat >>"$SB/hyprland.lua" <<EOF
dofile("$WORKSPACES")
dofile("$SPECIALS")
lyne_specials({
    { id = "smoke-empty", name = "Smoke empty", command = "touch $SB/launched-smoke-empty", class = "", keys = "", move_keys = "" },
    { id = "smoke-busy", name = "Smoke busy", command = "touch $SB/launched-smoke-busy", class = "^(smoke-busy)$", keys = "", move_keys = "" },
})
EOF
    cat >"$SB/nest.sh" <<EOF
#!/bin/bash
echo \$\$ >"$SB/nest.pid"
unset HYPRLAND_INSTANCE_SIGNATURE DISPLAY XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME
export WAYLAND_DISPLAY="$LIVE_WL" XDG_RUNTIME_DIR="$SB/run" HOME="$SB/home" LYNE_LID_STATE_FILE="$SB/lid-state"
exec Hyprland -c "$SB/hyprland.lua" >"$SB/hyprland.log" 2>&1
EOF
    chmod +x "$SB/nest.sh"
    # Through your Hyprland, so it lands hidden and unfocused
    hyprctl dispatch "hl.dsp.exec_cmd('$SB/nest.sh', { workspace = 'special:lyne-smoke silent' })" >/dev/null ||
        fail_early "couldn't start the nested Hyprland"
    local sock=""
    for _ in {1..100}; do
        sock="$(compgen -G "$SB/run/hypr/*/.socket.sock" | head -1)"
        [[ -n "$sock" ]] && compgen -G "$SB/run/wayland-*" | grep -vq lock && break
        sleep 0.1
    done
    [[ -n "$sock" ]] || fail_early "the nested Hyprland didn't start (log: $SB/hyprland.log)"
    NEST_SIG="$(basename "$(dirname "$sock")")"
    NEST_WL="$(basename "$(compgen -G "$SB/run/wayland-*" | grep -v lock | head -1)")"
}

start_shell() {
    # A session bus of its own that starts nothing by itself (no portals)
    cat >"$SB/session.conf" <<EOF
<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-Bus Bus Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>
  <type>session</type>
  <listen>unix:dir=$SB/run</listen>
  <auth>EXTERNAL</auth>
  <policy context="default">
    <allow send_destination="*" eavesdrop="true"/>
    <allow eavesdrop="true"/>
    <allow own="*"/>
  </policy>
</busconfig>
EOF
    (
        cd "$SB" || exit 1
        exec env -i HOME="$SB/home" USER="$USER" LANG="${LANG:-en_US.UTF-8}" TERM=xterm \
            PATH="$SB/bin:/usr/bin:$REPO/local/.local/bin" XDG_RUNTIME_DIR="$SB/run" \
            WAYLAND_DISPLAY="$NEST_WL" HYPRLAND_INSTANCE_SIGNATURE="$NEST_SIG" \
            XDG_CURRENT_DESKTOP=Hyprland XDG_DATA_DIRS="/usr/local/share:/usr/share:$SB/home/.local/share" \
            QT_QPA_PLATFORM=wayland QT_QPA_PLATFORMTHEME=qt6ct QT_WAYLAND_DISABLE_WINDOWDECORATION=1 \
            XCURSOR_THEME="$(jq -r .cursor.theme "$SB/cfg/state.json")" XCURSOR_SIZE="$(jq -r .cursor.size "$SB/cfg/state.json")" \
            QT_FORCE_STDERR_LOGGING=1 \
            LYNE_SDDM_DIR="$SB/sddm" LYNE_DOTS="$SB/home/.lyne-dots" \
            /usr/bin/setsid dbus-run-session --config-file="$SB/session.conf" -- qs -p "$SB/cfg/shell.qml"
    ) >"$SB/qs.log" 2>&1 &
    for _ in {1..300}; do
        grep -q "Configuration Loaded" "$SB/qs.log" && return 0
        grep -q "Failed to load configuration" "$SB/qs.log" && break
        sleep 0.1
    done
    sed 's/\x1b\[[0-9;]*m//g' "$SB/qs.log" | grep -E 'ERROR|caused by' >&2
    fail_early "the shell didn't load"
}

ev() { XDG_RUNTIME_DIR="$SB/run" qs ipc -p "$SB/cfg/shell.qml" call smoke ev "$1" 2>&1; }
ipc() { XDG_RUNTIME_DIR="$SB/run" qs ipc -p "$SB/cfg/shell.qml" call "$@" 2>&1; }

# -----------------------------------------------------------------------------
# Steps: each one runs, waits, and its new log lines are checked
# -----------------------------------------------------------------------------
FAILURES=()
STEPS=0
LOG_MARK=0

# Problem lines logged between two line counts (warnings and errors, minus
# the expected ones)
problems_between() {
    sed -n "$(($1 + 1)),$2p" "$SB/qs.log" | sed 's/\x1b\[[0-9;]*m//g' |
        grep -E '(WARN|ERROR|CRIT|FATAL)|TypeError|ReferenceError|is not defined|Cannot read property|Unable to assign' |
        grep -vEf <(grep -vE '^(#|$)' "$ALLOWED")
}

# step LABEL ev|ipc ARGS...
step() {
    local label="$1" kind="$2" out problems
    shift 2
    STEPS=$((STEPS + 1))
    if [[ "$kind" == ev ]]; then out="$(ev "$1")"; else out="$(ipc "$@")"; fi
    sleep "$WAIT"
    local total
    total="$(wc -l <"$SB/qs.log")"
    problems="$(problems_between "$LOG_MARK" "$total")"
    LOG_MARK="$total"
    if [[ "$out" == ERROR* || "$out" == *"No such"* || "$out" == *"not found"* ]]; then
        problems+="${problems:+$'\n'}call: $out"
    fi
    if [[ -n "$problems" ]]; then
        FAILURES+=("$label:"$'\n'"$(awk '{ print "    " $0 }' <<<"$problems")")
        printf '%s✗%s %s\n' "$C_FAIL" "$C_OFF" "$label"
    else
        printf '%s✓%s %s\n' "$C_OK" "$C_OFF" "$label"
    fi
}

# check LABEL COMMAND...: a step that runs a command here (retried for up to
# 3 s: the shell writes files a moment after a change)
check() {
    local label="$1"
    shift
    STEPS=$((STEPS + 1))
    local _
    for _ in {1..15}; do
        "$@" >/dev/null 2>&1 && break
        sleep 0.2
    done
    if "$@" >/dev/null 2>&1; then
        printf '%s✓%s %s\n' "$C_OK" "$C_OFF" "$label"
    else
        FAILURES+=("$label:"$'\n'"    failed: $*")
        printf '%s✗%s %s\n' "$C_FAIL" "$C_OFF" "$label"
    fi
}

# ev_is VALUE JS: the shell answers VALUE (for check)
ev_is() { [[ "$(ev "$2")" == "$1" ]]; }

# ev_soon VALUE JS: ev_is within 8 s (after an event the shell reads again)
ev_soon() {
    local _
    for _ in {1..32}; do
        ev_is "$1" "$2" && return 0
        sleep 0.25
    done
    return 1
}

# CursorService quotes a name with quotes in it so sh reads it back as is
cursor_quote_ok() {
    local quoted
    quoted="$(ev 'CursorService._quote("it\x27s a \"test\"")')"
    [[ "$(sh -c "printf %s $quoted")" == "it's a \"test\"" ]]
}

# hyprctl of the nested Hyprland
nested() { XDG_RUNTIME_DIR="$SB/run" HYPRLAND_INSTANCE_SIGNATURE="$NEST_SIG" hyprctl "$@"; }

nothing_deprecated() { [[ "$(nested deprecated-config)" == "all good!" ]]; }

# The special a window of CLASS opened in
window_in() { [[ "$(nested clients -j | jq -r --arg c "$2" '.[] | select(.class == $c) | .workspace.name')" == "$1" ]]; }

# A special created by a window opening in it isn't empty: its app stays
# closed (a moment after the window, for the event to have come). kitty may
# take a while to start on a busy machine: up to 10 s
busy_special_not_launched() {
    local _
    for _ in {1..50}; do
        window_in special:smoke-busy smoke-busy && break
        sleep 0.2
    done
    window_in special:smoke-busy smoke-busy || return 1
    sleep 0.5
    [[ ! -e "$SB/launched-smoke-busy" ]]
}

# workspace_step DIRECTION OFFSET: the bar's next/previous (mouse wheel, the
# same as Super + Ctrl + H/L) lands OFFSET away from WS_START
active_id() { nested activeworkspace -j | jq -r .id; }
workspace_step() {
    local monitor want=$((WS_START + $2))
    monitor="$(nested monitors -j | jq -r '.[0].name')"
    [[ "$(active_id)" == "$want" ]] && return 0
    nested dispatch "lyne_workspace_step($1, \"$monitor\")" | grep -qx ok || return 1
    [[ "$(active_id)" == "$want" ]]
}

# A list from the shell, as words: list JS
list() { ev "$1" | tr ',' ' '; }

# JS that answers "ok" when the shell shows LANG (a string every language
# file has, translated), an ERROR otherwise
language_is() {
    local want="$1" word="Language"
    [[ "$want" == en ]] || word="$(jq -r '.Language' "$SHELL_DIR/i18n/$want.json")"
    printf 'I18n.language === "%s" && I18n.tr("Language") === "%s" ? "ok" : "ERROR shows " + I18n.language + ": " + I18n.tr("Language")' "$want" "$word"
}

run_steps() {
    local id
    step "start" ev '"ok"'
    check "specials › nothing deprecated" nothing_deprecated
    nested dispatch 'hl.dsp.workspace.toggle_special("smoke-empty")' >/dev/null
    check "specials › shown empty opens the app" test -e "$SB/launched-smoke-empty"
    nested dispatch 'hl.dsp.workspace.toggle_special("smoke-empty")' >/dev/null
    nested dispatch "hl.dsp.exec_cmd('/usr/bin/kitty --class smoke-busy -e sleep 60')" >/dev/null
    check "specials › created by a window opens nothing" busy_special_not_launched
    # special:smoke-busy is still open (kitty): next/previous skip it
    WS_START="$(active_id)"
    check "workspaces › next with a special open" workspace_step 1 1
    check "workspaces › previous with a special open" workspace_step -1 0
    step "language › pt_BR from the state" ev "$(language_is pt_BR)"
    # Settings search: the translated row, found in both languages
    step "search › index" ev 'SettingsService.buildIndex(); "ok"'
    step "search › pt_BR and English words" ev 'const hit = q => SettingsService.search(q).some(e => e.page === "profile" && e.label === I18n.tr("Language")); hit("idioma") && hit("language") ? "ok" : "ERROR search: " + JSON.stringify(SettingsService.search("idioma").slice(0, 3).map(e => e.label))'

    for id in $(list 'SettingsService.pages.map(p => p.id)'); do
        step "settings › $id" ev "SettingsService.open('$id')"
    done
    step "settings closed" ipc settings close

    for id in $(list 'DashboardService.allTabs.map(t => t.id)'); do
        step "dashboard › $id" ipc dashboard open "$id"
    done
    step "dashboard closed" ipc dashboard close

    for id in $(list 'Object.keys(QuickSettingsService.pages).filter(k => k !== "")'); do
        step "quick settings › $id" ipc quicksettings open "$id"
    done
    step "quick settings closed" ipc quicksettings close
    # With a cable the Wi-Fi tile shows it (and lights up)
    # (the label and status as the shell's language says them)
    local tile='const t = QuickSettingsService.allTiles.find(t => t.tileId === "wifi"); [t.label, t.status, t.active].join("|")'
    cable on
    check "network › the tile shows the cable" ev_soon "$(ev 'I18n.tr("Network") + "|" + I18n.tr("Wired")')|true" "$tile"
    step "quick settings › wifi with a cable" ipc quicksettings open wifi
    check "network › the page reads the cable's details" ev_soon "1000 192.168.1.7" 'NetworkService.wiredDetails.speed + " " + NetworkService.wiredDetails.ip'
    cable off
    check "network › unplugged, the tile is Wi-Fi again" ev_soon "$(ev 'I18n.tr("Wi-Fi") + "|" + I18n.tr("On")')|true" "$tile"
    step "quick settings › wifi without it" ipc quicksettings close
    # A shortcut closes the popup, then opens its Settings page
    step "quick settings › shortcut" ev 'QuickSettingsService.open("", QuickSettingsService.focusedScreen()); QuickSettingsService.runShortcut("settings", "keybinds"); "ok"'
    check "quick settings › shortcut closed it" ev_is "" 'QuickSettingsService.screen'
    check "quick settings › shortcut opened settings" ev_is true 'SettingsService.visible && SettingsService.currentPage === "keybinds"'
    step "quick settings › shortcut settings closed" ipc settings close

    for id in $(list 'LauncherService.modes.map(m => m.id)'); do
        step "launcher › $id" ev "LauncherService.showMode('$id')"
    done
    step "launcher closed" ipc launcher close
    # Usage is only counted while the list is ranked by it
    local counted='LauncherService.usage.some(u => u.id === "smoke-app")'
    ev 'StateService.set("launcher.rankByUsage", false); LauncherService._recordUsage("smoke-app"); "ok"' >/dev/null
    check "launcher › rank by usage off: nothing counted" ev_is false "$counted"
    ev 'StateService.set("launcher.rankByUsage", true); LauncherService._recordUsage("smoke-app"); "ok"' >/dev/null
    check "launcher › rank by usage on: counted" ev_is true "$counted"
    ev 'LauncherService.clearUsage(); "ok"' >/dev/null

    step "notifications window" ipc notifications toggleWindow
    step "notifications closed" ipc notifications toggleWindow
    step "notification popup" ev 'Quickshell.execDetached(["notify-send", "-a", "Smoke", "Smoke test", "A notification body"]); "sent"'
    step "power menu" ipc power open
    step "power menu closed" ipc power close
    # Leaving the session saves tmux first. A reboot, so only once systemctl
    # is known to be the stand-in
    step "power › systemctl probe" ev 'Quickshell.execDetached(["systemctl", "smoke-probe"]); "sent"'
    check "power › systemctl is the stand-in" grep -q "^systemctl smoke-probe" "$SB/calls.log"
    if grep -q "^systemctl smoke-probe" "$SB/calls.log"; then
        step "power › reboot (stand-ins)" ev 'PowerService.execute("reboot"); "asked"'
        check "power › tmux saved before the reboot" saved_before_reboot
    fi
    step "wallpaper picker" ipc wallpapers open
    step "wallpaper picker closed" ipc wallpapers close
    for id in volume mic brightness layout tiling; do
        step "osd › $id" ev "OsdService.show('$id')"
    done
    step "welcome" ipc welcome open
    for _ in 1 2 3 4 5 6 7; do
        step "welcome › next" ev 'WelcomeService.next()'
    done
    step "welcome closed" ipc welcome close
    step "what's new" ipc whatsnew open ""
    step "what's new closed" ipc whatsnew close
    step "lock" ipc lock lock
    # What a right password does: the lock screen releases the session lock
    step "unlock" ev 'LockService.authSucceeded()'
    step "theme › catppuccin-latte" ev "ThemeService.setPresetMode('catppuccin-latte')"
    step "theme › tokyonight" ev "ThemeService.setPresetMode('tokyonight')"
    step "theme › auto" ev "ThemeService.setAutoMode()"

    # Cursor: the themes found, and a switch reaching GTK, the default theme
    # and Hyprland's file
    step "cursor › themes" ev 'CursorService.loaded && CursorService.current !== null ? "ok" : "ERROR cursor themes: " + JSON.stringify(CursorService.themes.map(t => t.id))'
    step "cursor › Adwaita 32" ev 'CursorService.setTheme("Adwaita"); CursorService.setSize(32); "ok"'
    # Apps the launcher starts get the new cursor, not the shell's own
    check "cursor › launcher env" ev_is "export XCURSOR_THEME='Adwaita' XCURSOR_SIZE=32; " 'CursorService.shellEnv'
    check "cursor › env quoting" cursor_quote_ok
    check "cursor › applied" grep -q "gsettings set org.gnome.desktop.interface cursor-theme Adwaita" "$SB/calls.log"
    check "cursor › default theme" grep -qx "Inherits=Adwaita" "$SB/home/.icons/default/index.theme"
    check "cursor › previews" test -s "$SB/home/.cache/lyne/cursors/Adwaita/default-32.png"
    check "cursor › settings.lua" grep -qF 'hl.env("XCURSOR_SIZE", "32", true)' "$SB/home/.config/hypr/local/settings.lua"
    # A theme copied into the user's folder: listed, removable, removed
    mkdir -p "$SB/home/.local/share/icons/Smoke-Cursor/cursors"
    cp /usr/share/icons/Adwaita/cursors/default "$SB/home/.local/share/icons/Smoke-Cursor/cursors/"
    step "cursor › refresh" ev 'CursorService.refresh(); "ok"'
    check "cursor › copied theme listed" ev_is true 'CursorService.themes.some(t => t.id === "Smoke-Cursor" && t.removable)'
    step "cursor › remove" ev 'CursorService.remove("Smoke-Cursor"); "ok"'
    check "cursor › removed" test ! -e "$SB/home/.local/share/icons/Smoke-Cursor"
    step "cursor › back to the default" ev 'StateService.set("cursor.theme", StateService.getDefault("cursor.theme", "")); StateService.set("cursor.size", StateService.getDefault("cursor.size", 24)); "ok"'

    # Icons: a family with dark and light versions in the user's folder; the
    # dark one reaches GTK, Qt and KDE, then the shell's icons load again
    local variant
    for variant in "" -dark -light; do
        mkdir -p "$SB/home/.local/share/icons/Smoke-Icons$variant"
        printf '[Icon Theme]\nName=Smoke Icons%s\nInherits=hicolor\nDirectories=48/apps\n\n[48/apps]\nSize=48\n' "$variant" \
            >"$SB/home/.local/share/icons/Smoke-Icons$variant/index.theme"
        mkdir -p "$SB/home/.local/share/icons/Smoke-Icons$variant/48/apps"
        cp /usr/share/icons/hicolor/48x48/apps/*.png "$SB/home/.local/share/icons/Smoke-Icons$variant/48/apps/folder.png" 2>/dev/null ||
            printf 'png' >"$SB/home/.local/share/icons/Smoke-Icons$variant/48/apps/folder.png"
    done
    step "icons › refresh" ev 'IconService.refresh(); "ok"'
    check "icons › previews" ev_is "file://$SB/home/.local/share/icons/Smoke-Icons-light/48/apps/folder.png" 'IconService.previewUrl("Smoke-Icons-light", "folder")'
    check "icons › family listed" ev_is "Smoke-Icons-dark Smoke-Icons-light" 'const t = IconService.themes.find(t => t.id === "Smoke-Icons"); t ? t.dark + " " + t.light : JSON.stringify(IconService.themes.map(t => t.id))'
    step "icons › Smoke-Icons" ev 'IconService.setTheme("Smoke-Icons"); "ok"'
    check "icons › variant" ev_is Smoke-Icons-dark 'IconService.variant'
    check "icons › gsettings" grep -q "gsettings set org.gnome.desktop.interface icon-theme Smoke-Icons-dark" "$SB/calls.log"
    check "icons › qt6ct" grep -qx "icon_theme=Smoke-Icons-dark" "$SB/home/.config/qt6ct/qt6ct.conf"
    check "icons › kdeglobals" grep -qx "Theme=Smoke-Icons-dark" "$SB/home/.config/kdeglobals"
    check "icons › gtk settings.ini" grep -qx "gtk-icon-theme-name=Smoke-Icons-dark" "$SB/home/.config/gtk-4.0/settings.ini"
    # After qt6ct's reload: KIconLoader told, the icon URLs changed
    sleep 2
    check "icons › KDE apps told" grep -q "dbus-send .*org.kde.KIconLoader.iconChanged" "$SB/calls.log"
    check "icons › new icon urls" ev_is "image://icon/folder?path=lyne-icons-1" 'IconService.url("folder", "")'
    check "icons › light variant" ev_is Smoke-Icons-light 'IconService.variantOf(IconService.current, false)'
    step "icons › back to the default" ev 'StateService.set("icons.theme", StateService.getDefault("icons.theme", "")); "ok"'
    # The family is the user's: removable, and removed with its versions
    check "icons › removable" ev_is true 'IconService.themes.some(t => t.id === "Smoke-Icons" && t.removable)'
    step "icons › remove" ev 'IconService.remove("Smoke-Icons"); "ok"'
    check "icons › removed" test ! -e "$SB/home/.local/share/icons/Smoke-Icons-dark"
    check "icons › list without it" ev_is false 'IconService.themes.some(t => t.id === "Smoke-Icons")'

    # Language switched live, with translated windows open
    step "language › open windows" ev 'SettingsService.open("profile"); WelcomeService.open(); "ok"'
    for id in en pt_BR en; do
        step "language › $id (live)" ev "StateService.set('general.language', '$id'); 'ok'"
        step "language › $id shows" ev "$(language_is "$id")"
    done
    step "language › windows closed" ev 'SettingsService.close(); WelcomeService.close(); "ok"'
}

# -----------------------------------------------------------------------------
build_sandbox
start_nested
start_shell
# Loading itself: the lines logged until now
sleep 2
run_steps

# Nothing outside the sandbox changed
[[ "$(sha1sum "$LIVE_STATE" 2>/dev/null)" == "$live_state_sum" ]] ||
    FAILURES+=("outside the sandbox: your $LIVE_STATE changed")
[[ "$(sha1sum "$LIVE_WS_STATE" 2>/dev/null)" == "$live_ws_state_sum" ]] ||
    FAILURES+=("outside the sandbox: your $LIVE_WS_STATE changed")
[[ "$(git -C "$REPO" status --porcelain)" == "$repo_status" ]] ||
    FAILURES+=("outside the sandbox: the repo changed:"$'\n'"$(git -C "$REPO" status --porcelain)")

echo ""
if ((${#FAILURES[@]})); then
    printf '%s%d of %d steps logged problems:%s\n' "$C_FAIL" "${#FAILURES[@]}" "$STEPS" "$C_OFF"
    printf '  %s\n' "${FAILURES[@]}"
    echo "${C_DIM}Full log: SMOKE_KEEP=1 tests/qml/smoke.sh, then \$SB/qs.log${C_OFF}"
    exit 1
fi
printf '%s%d steps, no QML errors%s\n' "$C_OK" "$STEPS" "$C_OFF"
