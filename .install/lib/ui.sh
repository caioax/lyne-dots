#!/bin/bash
# =============================================================================
# ui.sh - Full-screen drawing for the installer (plain bash, no dependencies)
# =============================================================================
# A frame is built line by line (ui_add) and drawn at once (ui_flush) over
# the previous one, so redraws don't flicker. The Linux console (TERM=linux,
# where a fresh Arch install usually runs) has no braille or check marks in
# its font: it gets an ASCII set. LYNE_ASCII=1 forces it.
# Usage: source this file
# =============================================================================

UI_LINES=()
UI_ACTIVE=0

ui_setup() {
    local charmap
    charmap="$(locale charmap 2>/dev/null)"
    if [[ "${LYNE_ASCII:-}" == 1 || "$TERM" == linux || "$charmap" != UTF-8 ]]; then
        G_CURSOR=">" G_ON="[x]" G_OFF="[ ]" G_RADIO_ON="(*)" G_RADIO_OFF="( )"
        G_OK="+" G_FAIL="x" G_WARN="!" G_SKIP="-" G_TODO=" " G_DOT="-"
        G_FULL="#" G_EMPTY="-" G_PIPE="|" G_RULE="-" G_ELLIPSIS="..." G_UPDOWN="up/down"
        G_SPIN=('|' '/' '-' '\')
    else
        G_CURSOR="▶" G_ON="[x]" G_OFF="[ ]" G_RADIO_ON="(•)" G_RADIO_OFF="( )"
        G_OK="✓" G_FAIL="✗" G_WARN="!" G_SKIP="–" G_TODO=" " G_DOT="·"
        G_FULL="█" G_EMPTY="░" G_PIPE="│" G_RULE="─" G_ELLIPSIS="…" G_UPDOWN="↑/↓"
        G_SPIN=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    fi

    # 16-color escapes only: the Linux console has nothing else
    C_RESET=$'\033[0m' C_BOLD=$'\033[1m' C_DIM=$'\033[2m'
    C_ACCENT=$'\033[34m' C_SEL=$'\033[1;36m' C_OK=$'\033[32m'
    C_WARN=$'\033[33m' C_FAIL=$'\033[31m'
}

ui_size() {
    local size
    size="$(stty size </dev/tty 2>/dev/null)"
    UI_ROWS="${size% *}" UI_COLS="${size#* }"
    [[ "$UI_ROWS" =~ ^[0-9]+$ ]] || UI_ROWS=24
    [[ "$UI_COLS" =~ ^[0-9]+$ ]] || UI_COLS=80
    # Text width inside the 2-column margin, capped so wide terminals keep a
    # readable column
    UI_WIDTH=$((UI_COLS - 4))
    ((UI_WIDTH > 76)) && UI_WIDTH=76
    ((UI_WIDTH < 20)) && UI_WIDTH=20
}

# Alternate screen and hidden cursor. Keys aren't echoed while ui_read_key
# waits (read -s); screens that don't read (the install) turn echo off with
# ui_keys_off. The terminal's own settings come back on ui_leave: a read
# interrupted by Ctrl+C restores what it saw, so echo is never turned off
# around one
ui_enter() {
    ((UI_ACTIVE)) && return
    UI_ACTIVE=1
    [[ -n "${UI_STTY:-}" ]] || UI_STTY="$(stty -g </dev/tty 2>/dev/null)"
    printf '\033[?1049h\033[?25l\033[H\033[2J' >/dev/tty
}

ui_keys_off() {
    stty -echo </dev/tty 2>/dev/null
}

ui_leave() {
    ((UI_ACTIVE)) || return
    UI_ACTIVE=0
    printf '\033[0m\033[?25h\033[?1049l' >/dev/tty
    [[ -n "${UI_STTY:-}" ]] && stty "$UI_STTY" </dev/tty 2>/dev/null
}

# Cuts plain text to a width, marking the cut
ui_fit() {
    local text=$1 width=$2
    if ((${#text} > width)); then
        local keep=$((width - ${#G_ELLIPSIS}))
        ((keep < 0)) && keep=0
        text="${text:0:keep}$G_ELLIPSIS"
    fi
    printf '%s' "$text"
}

# Pads plain text to a width (after cutting it)
ui_pad() {
    local text
    text="$(ui_fit "$1" "$2")"
    printf '%s%*s' "$text" $(($2 - ${#text})) ""
}

ui_frame() { UI_LINES=(); ui_size; }

# One line of the frame, already colored by the caller; the caller keeps its
# visible text inside UI_WIDTH (ui_fit/ui_pad)
ui_add() { UI_LINES+=("  $1"); }

ui_flush() {
    local out=$'\033[H' line
    for line in "${UI_LINES[@]}"; do
        out+="$line$C_RESET"$'\033[K\n'
    done
    printf '%s\033[J' "$out" >/dev/tty
}

ui_banner() {
    UI_LINES+=("")
    ui_add "$C_ACCENT█   █▄█ █▄ █ █▀▀ ▄▄ █▀▄ █▀█ ▀█▀ █▀$C_RESET"
    ui_add "$C_ACCENT█▄▄  █  █ ▀█ ██▄    █▄▀ █▄█  █  ▄█$C_RESET   ${C_DIM}installer${LYNE_DRY_RUN:+ (dry run)}$C_RESET"
    UI_LINES+=("")
}

# Title with an optional right-aligned note (like "2/4") and a rule
ui_title() {
    local title=$1 note=${2:-}
    local width=$((UI_WIDTH - ${#note} - 1))
    ui_add "$C_BOLD$(ui_pad "$title" "$width")$C_RESET $C_DIM$note$C_RESET"
    local rule
    printf -v rule '%*s' "$UI_WIDTH" ""
    ui_add "$C_DIM${rule// /$G_RULE}$C_RESET"
}

# Wrapped plain paragraph
ui_text() {
    local style=${2:-} line="" word words
    read -ra words <<<"$1"
    for word in "${words[@]}"; do
        if [[ -z "$line" ]]; then
            line=$word
        elif ((${#line} + 1 + ${#word} <= UI_WIDTH)); then
            line+=" $word"
        else
            ui_add "$style$line$C_RESET"
            line=$word
        fi
    done
    [[ -n "$line" ]] && ui_add "$style$line$C_RESET"
}

ui_hint() {
    UI_LINES+=("")
    ui_add "$C_DIM$(ui_fit "$1" "$UI_WIDTH")$C_RESET"
}

# Reads one key from the terminal into KEY: up, down, left, right, enter,
# space, esc, eof, or the character itself
ui_read_key() {
    local k rest
    if ! IFS= read -rsn1 k </dev/tty; then
        KEY=eof
        return
    fi
    case "$k" in
    $'\033')
        IFS= read -rsn2 -t 0.05 rest </dev/tty
        case "$rest" in
        '[A' | 'OA') KEY=up ;;
        '[B' | 'OB') KEY=down ;;
        '[C' | 'OC') KEY=right ;;
        '[D' | 'OD') KEY=left ;;
        '') KEY=esc ;;
        *)
            # Drain the rest of a longer sequence (F keys, Home...)
            IFS= read -rsn8 -t 0.01 rest </dev/tty
            KEY=other
            ;;
        esac
        ;;
    '') KEY=enter ;;
    ' ') KEY=space ;;
    *) KEY=$k ;;
    esac
}
