#!/usr/bin/env bash
# Runs the lyne-dots test suite: tests/run.sh [section...]
#   js     node tests of the shell's JavaScript libraries (tests/js)
#   bash   bats tests of the lyne CLI, migrations and installer (tests/bash)
#   lint   shellcheck over every script in the repo, the tests included
#   qml    qmllint over the shell, against tests/qml/lint-baseline.txt
#   smoke  the whole shell in a nested Hyprland, every window and page
#          opened, no QML errors (needs a running Hyprland session)
#   nvim   Neovim inside tmux: Ctrl/Alt + h/j/k/l between Neovim's splits
#          and tmux's panes; the config with the LSP on, nothing deprecated;
#          the shortcut search (prefix + ?); sessions saved and restored;
#          the popups (lazygit, scratch, projects); the color preview;
#          QML (Treesitter, qmlls finding Quickshell's modules); one
#          Neovim per project (its socket) and lyne nvim open
#          (needs tmux and the plugins lazy.nvim and Mason installed)
# No section = all of them. Exits 1 when a section fails or its tool is
# missing (nothing is skipped silently).
# shellcheck disable=SC2329  # run_<section> is called as "run_$s"

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

if [[ -t 1 ]]; then
    C_BOLD=$'\e[1m' C_DIM=$'\e[2m' C_OK=$'\e[32m' C_FAIL=$'\e[31m' C_OFF=$'\e[0m'
else
    C_BOLD="" C_DIM="" C_OK="" C_FAIL="" C_OFF=""
fi

SECTIONS=(js bash lint qml smoke nvim)
declare -A RESULT

header() { printf '\n%s== %s ==%s\n' "$C_BOLD" "$1" "$C_OFF"; }

# need TOOL PACKAGE: fails the section with how to install the tool
need() {
    command -v "$1" >/dev/null && return 0
    printf '%smissing %s: sudo pacman -S %s%s\n' "$C_FAIL" "$1" "$2" "$C_OFF"
    return 1
}

run_js() {
    need node nodejs || return 1
    node --test tests/js/
}

run_bash() {
    if ! compgen -G "tests/bash/*.bats" >/dev/null; then
        printf '%sno tests yet%s\n' "$C_DIM" "$C_OFF"
        return 0
    fi
    need bats "bats bats-assert bats-support" || return 1
    bats --recursive tests/bash
}

run_lint() {
    need shellcheck shellcheck || return 1
    local files
    # Tracked and new (not ignored) scripts
    mapfile -t files < <(git ls-files --cached --others --exclude-standard '*.sh' '*.bats' '*.bash' \
        local/.local/bin/lyne 'tests/bash/stubs/*')
    # A tracked script deleted but not committed yet is still listed
    local f existing=()
    for f in "${files[@]}"; do [[ -f "$f" ]] && existing+=("$f"); done
    files=("${existing[@]}")
    printf 'shellcheck: %d scripts\n' "${#files[@]}"
    shellcheck -x "${files[@]}" && printf '%sclean%s\n' "$C_OK" "$C_OFF"
}

run_qml() {
    tests/qml/lint.sh
}

run_smoke() {
    tests/qml/smoke.sh
}

run_nvim() {
    need tmux tmux || return 1
    need nvim neovim || return 1
    need git git || return 1
    local ok=0
    tests/nvim/nav.sh || ok=1
    tests/nvim/config.sh || ok=1
    tests/nvim/shortcuts.sh || ok=1
    tests/nvim/sessions.sh || ok=1
    tests/nvim/popups.sh || ok=1
    tests/nvim/colors.sh || ok=1
    tests/nvim/qml.sh || ok=1
    tests/nvim/instance.sh || ok=1
    tests/nvim/open.sh || ok=1
    return "$ok"
}

selected=("$@")
[[ ${#selected[@]} -eq 0 ]] && selected=("${SECTIONS[@]}")
for s in "${selected[@]}"; do
    if [[ " ${SECTIONS[*]} " != *" $s "* ]]; then
        echo "unknown section: $s (sections: ${SECTIONS[*]})" >&2
        exit 2
    fi
done

failed=0
for s in "${selected[@]}"; do
    header "$s"
    if "run_$s"; then
        RESULT[$s]="${C_OK}ok${C_OFF}"
    else
        RESULT[$s]="${C_FAIL}FAILED${C_OFF}"
        failed=1
    fi
done

header summary
for s in "${selected[@]}"; do
    printf '  %-6s %s\n' "$s" "${RESULT[$s]}"
done
exit "$failed"
