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
# switched live (en, pt_BR, en). It fails on any QML error or warning
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
# =============================================================================

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# SMOKE_SHELL: another copy of the shell config (a test that it fails)
SHELL_DIR="${SMOKE_SHELL:-$REPO/quickshell/.config/quickshell}"
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
    for pkg in theming kde kitty; do cp -r "$REPO/$pkg/.config/." "$home/.config/"; done
    mkdir -p "$home/.config/hypr/local"
    local dir theme
    for dir in "$REPO"/.data/wallpapers/themes/*/; do
        theme="$(basename "$dir")"
        mkdir -p "$home/.local/wallpapers/themes/$theme"
        cp "$dir"lyne-*-contour.jpg "$home/.local/wallpapers/themes/$theme/" 2>/dev/null
        cp "$dir"lyne-*-contour.jpg "$home/.local/wallpapers/" 2>/dev/null
    done

    local t
    for t in nmcli rfkill brightnessctl ddcutil hyprsunset kitty nvim loginctl zenity \
        awww awww-daemon gsettings systemctl systemd-inhibit pkill killall xdg-open setsid \
        missioncenter kwriteconfig6 kbuildsycoca6 powerprofilesctl lyne-sddm grim slurp satty \
        wpctl pactl playerctl bluetoothctl cava; do
        printf '#!/bin/bash\necho "%s $*" >>"%s/calls.log"\n' "$t" "$SB" >"$SB/bin/$t"
        chmod +x "$SB/bin/$t"
    done
}

# -----------------------------------------------------------------------------
# Nested Hyprland, then the shell inside it
# -----------------------------------------------------------------------------
start_nested() {
    cat >"$SB/hyprland.lua" <<'EOF'
hl.monitor({ output = "", mode = "1920x1080", position = "0x0", scale = 1 })
hl.config({ xwayland = { enabled = false }, animations = { enabled = false } })
EOF
    cat >"$SB/nest.sh" <<EOF
#!/bin/bash
echo \$\$ >"$SB/nest.pid"
unset HYPRLAND_INSTANCE_SIGNATURE DISPLAY
export WAYLAND_DISPLAY="$LIVE_WL" XDG_RUNTIME_DIR="$SB/run" HOME="$SB/home"
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
            XDG_CURRENT_DESKTOP=Hyprland XDG_DATA_DIRS="/usr/local/share:/usr/share:$HOME/.local/share" \
            QT_QPA_PLATFORM=wayland QT_QPA_PLATFORMTHEME=qt6ct QT_WAYLAND_DISABLE_WINDOWDECORATION=1 \
            XCURSOR_THEME="$(jq -r .cursor.theme "$SB/cfg/state.json")" XCURSOR_SIZE="$(jq -r .cursor.size "$SB/cfg/state.json")" \
            QT_FORCE_STDERR_LOGGING=1 \
            LYNE_SDDM_DIR="$SB/sddm" \
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

    for id in $(list 'LauncherService.modes.map(m => m.id)'); do
        step "launcher › $id" ev "LauncherService.showMode('$id')"
    done
    step "launcher closed" ipc launcher close

    step "notifications window" ipc notifications toggleWindow
    step "notifications closed" ipc notifications toggleWindow
    step "notification popup" ev 'Quickshell.execDetached(["notify-send", "-a", "Smoke", "Smoke test", "A notification body"]); "sent"'
    step "power menu" ipc power open
    step "power menu closed" ipc power close
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
