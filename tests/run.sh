#!/usr/bin/env bash
# Runs the lyne-dots test suite: tests/run.sh [section...]
#   js     node tests of the shell's JavaScript libraries (tests/js)
#   bash   bats tests of the lyne CLI, migrations and installer (tests/bash)
#   lint   shellcheck over every script in the repo
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

SECTIONS=(js bash lint)
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
    mapfile -t files < <(git ls-files --cached --others --exclude-standard '*.sh' local/.local/bin/lyne local/.local/bin/cpprun)
    printf 'shellcheck: %d scripts\n' "${#files[@]}"
    shellcheck -x "${files[@]}" && printf '%sclean%s\n' "$C_OK" "$C_OFF"
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
