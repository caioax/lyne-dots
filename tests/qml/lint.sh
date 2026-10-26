#!/usr/bin/env bash
# =============================================================================
# lint.sh - qmllint over every .qml of the shell, against a baseline
# =============================================================================
# qmllint doesn't know Quickshell well (PanelWindow "not creatable", layer
# anchors, types it can't resolve), so the warnings it gives today are kept
# in tests/qml/lint-baseline.txt, without line numbers, and only new ones
# fail. A baseline line that's gone is reported so the file can shrink.
#
# Usage: tests/qml/lint.sh            check
#        tests/qml/lint.sh --update   rewrite the baseline (after a review)
# =============================================================================

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# LINT_SHELL: another copy of the shell config (a test that it fails)
SHELL_DIR="${LINT_SHELL:-$REPO/quickshell/.config/quickshell}"
BASELINE="$REPO/tests/qml/lint-baseline.txt"
# /usr/bin/qmllint is Qt 5's
QMLLINT="${QMLLINT:-/usr/lib/qt6/bin/qmllint}"

[[ -x "$QMLLINT" ]] || {
    echo "qmllint (Qt 6) not found at $QMLLINT: sudo pacman -S qt6-declarative" >&2
    exit 1
}

# The shell imports its folders as qs.config and qs.services. They have no
# qmldir: Quickshell writes one for them (src/core/scan.cpp; its qmlls
# support only sees the ones it writes), and so does this, the same way: the
# module name, then each QML type, singleton when the file says pragma
# Singleton. The folders' files are copied next to it (qmllint follows links
# back to the real folder) and linted from there, so the types see their
# neighbours as singletons too
imports="$(mktemp -d)"
trap 'rm -rf "$imports"' EXIT
for dir in config services; do
    mkdir -p "$imports/qs/$dir"
    cp "$SHELL_DIR/$dir"/* "$imports/qs/$dir/"
    echo "module qs.$dir" >"$imports/qs/$dir/qmldir"
    for file in "$SHELL_DIR/$dir"/[A-Z]*.qml; do
        name="$(basename "$file" .qml)"
        grep -q '^pragma Singleton' "$file" && printf 'singleton ' >>"$imports/qs/$dir/qmldir"
        echo "$name 1.0 $name.qml" >>"$imports/qs/$dir/qmldir"
    done
done

# "file:line:col: message [category]" -> "file: message [category]"
lint() {
    find "$@" -name '*.qml' -printf '%P\0' | sort -z | xargs -0 "$QMLLINT" -I "$imports" 2>&1 |
        sed -nE 's/^(Warning|Info|Error): ([^:]+):[0-9]*:?[0-9]*:? (.*)$/\1: \2: \3/p'
}
current="$(
    {
        (cd "$SHELL_DIR" && lint . -path ./config -prune -o -path ./services -prune -o)
        (cd "$imports/qs" && lint .)
    } | sort -u
)"

if [[ "${1:-}" == --update ]]; then
    {
        echo "# qmllint warnings accepted today (tests/qml/lint.sh --update rewrites it)"
        echo "$current"
    } >"$BASELINE"
    echo "baseline: $(grep -vc '^#' "$BASELINE") warnings"
    exit 0
fi

baseline="$(grep -v '^#' "$BASELINE" 2>/dev/null | sort -u)"
new="$(comm -13 <(echo "$baseline") <(echo "$current") | grep -v '^$')"
gone="$(comm -23 <(echo "$baseline") <(echo "$current") | grep -vc '^$')"

echo "qmllint: $(find "$SHELL_DIR" -name '*.qml' | wc -l) files, $(echo "$current" | grep -c .) warnings in the baseline's terms"
((gone)) && echo "$gone baseline warning(s) are gone: tests/qml/lint.sh --update shrinks the file"
if [[ -n "$new" ]]; then
    echo "new warnings:"
    awk '{ print "  " $0 }' <<<"$new"
    exit 1
fi
echo "no new warnings"
