#!/bin/bash
# =============================================================================
# zen.sh - The lyne theme in Zen Browser profiles
# =============================================================================
# ThemeService writes the shell palette to ~/.cache/lyne/zen.json
# ({palette, scheme, opacity}); `lyne zen apply` turns it into CSS inside
# each enabled profile:
#   chrome/lyne.css           the UI (.data/zen/userChrome.css + colors)
#   chrome/lyne-content.css   about: pages (.data/zen/userContent.css)
#   chrome/userChrome.css     one `@import "lyne.css"; /* lyne-dots */` line
#   chrome/userContent.css    the same for lyne-content.css
#   user.js                   a marked block: stylesheets pref, transparency
# A profile is enabled when its userChrome.css has the import line. Files
# the user already had are copied to <file>.lyne-bak before the first edit,
# and only the marked lines are ever touched. Zen reads all of it at
# startup: a running Zen shows the new theme after a restart.
#
#   zen_profiles               root<TAB>name<TAB>dir<TAB>default per profile
#   zen_enabled <dir>          0 when the profile has the lyne theme
#   zen_running <dir>          0 when a Zen has the profile open
#   zen_json                   the profiles as JSON (Settings)
#   zen_apply [dir]            rewrite the CSS (one or every enabled profile)
#   zen_enable <dir>           add the theme to a profile
#   zen_disable <dir>          remove it, leaving the user's own CSS
#
# Options (state.json): zen.themeBackground (true: the theme background in
# every workspace; false: workspaces with their own gradient keep Zen's
# look), zen.transparent (the window follows the theme opacity, blurred).
# LYNE_ZEN_OPTIONS ({"themeBackground": .., "transparent": ..}) overrides
# them. LYNE_ZEN_ROOTS (colon separated), LYNE_STATE_FILE and
# LYNE_ZEN_PALETTE point it at test files.
# =============================================================================

ZEN_TEMPLATES="$DOTS_DIR/.data/zen"
ZEN_PALETTE="${LYNE_ZEN_PALETTE:-$HOME/.cache/lyne/zen.json}"
ZEN_STATE="${LYNE_STATE_FILE:-$DOTS_DIR/quickshell/.config/quickshell/state.json}"
ZEN_MARK="/* lyne-dots */"
ZEN_USERJS_BEGIN="// lyne-dots: begin (managed by lyne zen, edits here are lost)"
ZEN_USERJS_END="// lyne-dots: end"

# Profile roots Zen reads: like Firefox, a native install keeps the legacy
# ~/.zen while it exists and uses the XDG folder otherwise; plus Flatpak
_zen_roots() {
    local roots=()
    if [[ -n "${LYNE_ZEN_ROOTS:-}" ]]; then
        IFS=: read -ra roots <<< "$LYNE_ZEN_ROOTS"
    elif [[ -d "$HOME/.zen" ]]; then
        roots=("$HOME/.zen" "$HOME/.var/app/app.zen_browser.zen/.zen")
    else
        roots=("${XDG_CONFIG_HOME:-$HOME/.config}/zen" "$HOME/.var/app/app.zen_browser.zen/.zen")
    fi
    local r
    for r in "${roots[@]}"; do
        [[ -f "$r/profiles.ini" ]] && echo "$r"
    done
}

zen_profiles() {
    local root
    while IFS= read -r root; do
        # The profile Zen opens: installs.ini's Default, else Default=1
        local install_default
        install_default=$(sed -n 's/^Default=//p' "$root/installs.ini" 2>/dev/null | head -1)
        awk -F= -v root="$root" -v inst="$install_default" '
            function flush() {
                if (path != "") {
                    dir = rel ? root "/" path : path
                    def = (inst != "" ? path == inst : isdef) ? 1 : 0
                    printf "%s\t%s\t%s\t%d\n", root, name, dir, def
                }
                name = ""; path = ""; rel = 1; isdef = 0
            }
            /^\[/ { flush(); inprof = ($0 ~ /^\[Profile[0-9]+\]/); next }
            !inprof { next }
            $1 == "Name" { name = substr($0, 6) }
            $1 == "Path" { path = substr($0, 6) }
            $1 == "IsRelative" { rel = ($2 == "1") }
            $1 == "Default" { isdef = ($2 == "1") }
            END { flush() }
        ' "$root/profiles.ini" | while IFS=$'\t' read -r r n d def; do
            [[ -d "$d" ]] && printf '%s\t%s\t%s\t%s\n' "$r" "$n" "$d" "$def"
        done
    done < <(_zen_roots)
}

zen_enabled() {
    grep -qF "$ZEN_MARK" "$1/chrome/userChrome.css" 2>/dev/null
}

# The lock symlink points at "host:+pid" while Zen runs (stale after a crash)
zen_running() {
    local target pid
    target=$(readlink "$1/lock" 2>/dev/null) || return 1
    pid=${target##*+}
    [[ "$pid" =~ ^[0-9]+$ ]] || return 1
    grep -qi zen "/proc/$pid/comm" 2>/dev/null
}

zen_json() {
    local root name dir def
    while IFS=$'\t' read -r root name dir def; do
        local en=false run=false used=false
        zen_enabled "$dir" && en=true
        zen_running "$dir" && run=true
        # Zen creates an empty "Default Profile" it never opens
        [[ -f "$dir/prefs.js" ]] && used=true
        jq -nc --arg root "$root" --arg name "$name" --arg dir "$dir" \
            --argjson def "$([[ $def == 1 ]] && echo true || echo false)" \
            --argjson en "$en" --argjson run "$run" --argjson used "$used" \
            '{root: $root, name: $name, dir: $dir, default: $def, enabled: $en, running: $run, used: $used}'
    done < <(zen_profiles) | jq -sc '.'
}

# A boolean option: LYNE_ZEN_OPTIONS (a JSON object, from Quickshell, which
# saves state.json a moment later), then state.json, then the default
_zen_option() {
    local v=""
    [[ -n "${LYNE_ZEN_OPTIONS:-}" ]] &&
        v=$(jq -r --arg k "$1" '.[$k] | if type == "boolean" then . else empty end' <<< "$LYNE_ZEN_OPTIONS" 2>/dev/null)
    [[ -z "$v" ]] &&
        v=$(jq -r --arg k "$1" '.zen[$k] | if type == "boolean" then . else empty end' "$ZEN_STATE" 2>/dev/null)
    echo "${v:-$2}"
}

# The --lyne-* custom properties for the current palette. Colors are checked
# so a theme file can't put anything else into the CSS
_zen_vars() {
    [[ -f "$ZEN_PALETTE" ]] || { echo "No palette at $ZEN_PALETTE (switch themes once in the shell)" >&2; return 1; }
    local transparent
    transparent=$(_zen_option transparent false)
    jq -r --argjson transparent "$transparent" '
        def hex: if type == "string" and test("^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$") then . else error("bad color: \(.)") end;
        # WCAG relative luminance and contrast ratio
        def lum: [.[1:3], .[3:5], .[5:7]] | map(ascii_downcase | explode
            | map(if . >= 97 then . - 87 else . - 48 end) | (.[0] * 16 + .[1]) / 255
            | if . <= 0.04045 then . / 12.92 else pow((. + 0.055) / 1.055; 2.4) end)
            | .[0] * 0.2126 + .[1] * 0.7152 + .[2] * 0.0722;
        def contrast($a; $b): [($a | lum), ($b | lum)] | (max + 0.05) / (min + 0.05);
        .palette as $p
        | ($p.background | hex) as $bg
        | ($p.text | hex) as $fg
        | ($p.accent | hex) as $accent
        | (.scheme // (if ($bg | lum) < 0.18 then "dark" else "light" end)) as $scheme
        # Text on accent-filled buttons: whichever of background/text reads better
        | (if contrast($accent; $bg) >= contrast($accent; $fg) then $bg else $fg end) as $onAccent
        | ((.opacity // 1) * 100 | round) as $op
        | [
            ["background", $bg], ["surface0", $p.surface0], ["surface1", $p.surface1],
            ["surface2", $p.surface2], ["surface3", $p.surface3], ["text", $p.text],
            ["subtext", $p.subtext], ["muted", $p.muted], ["accent", $p.accent],
            ["on-accent", $onAccent], ["success", $p.success],
            ["warning", $p.warning], ["error", $p.error]
          ]
        | map("  --lyne-\(.[0]): \(.[1] | hex);") + [
            "  --lyne-window: \(if $transparent and $op < 100 then "color-mix(in srgb, \($bg) \($op)%, transparent)" else $bg end);",
            "  --lyne-base: \(if $transparent and $op < 100 then "transparent" else $bg end);",
            "  --lyne-scheme: \(if $scheme == "light" then "light" else "dark" end);"
          ]
        | join("\n")
    ' "$ZEN_PALETTE"
}

# Writes a file through a temp copy in the same directory
_zen_write() {
    local dest="$1" tmp
    tmp=$(mktemp "$dest.XXXXXX") || return 1
    cat > "$tmp" && mv -f "$tmp" "$dest"
}

# Keeps the user's own file once, before lyne-dots first edits it (a file
# that already has a lyne-dots mark isn't theirs anymore)
_zen_backup() {
    [[ -f "$1" && ! -e "$1.lyne-bak" ]] && ! grep -qF "lyne-dots" "$1" && cp -p "$1" "$1.lyne-bak"
    return 0
}

# Adds `@import "<css>"; /* lyne-dots */` at the top (imports must come
# before any other rule), unless it's there
_zen_add_import() {
    local file="$1" css="$2"
    grep -qF "$ZEN_MARK" "$file" 2>/dev/null && return 0
    _zen_backup "$file"
    { printf '@import "%s"; %s\n' "$css" "$ZEN_MARK"; cat "$file" 2>/dev/null; } | _zen_write "$file"
}

_zen_remove_import() {
    local file="$1"
    [[ -f "$file" ]] || return 0
    grep -vF "$ZEN_MARK" "$file" | _zen_write "$file"
    # A file that only held our line goes away
    grep -q '[^[:space:]]' "$file" || rm -f "$file"
}

_zen_userjs_strip() {
    awk -v b="$ZEN_USERJS_BEGIN" -v e="$ZEN_USERJS_END" '
        $0 == b { skip = 1; next }
        $0 == e { skip = 0; next }
        !skip
    ' "$1"
}

_zen_userjs_write() {
    local file="$1/user.js" transparent
    transparent=$(_zen_option transparent false)
    _zen_backup "$file"
    {
        [[ -f "$file" ]] && _zen_userjs_strip "$file"
        echo "$ZEN_USERJS_BEGIN"
        echo 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);'
        echo "user_pref(\"zen.widget.linux.transparency\", $transparent);"
        echo "$ZEN_USERJS_END"
    } | _zen_write "$file"
}

_zen_userjs_remove() {
    local file="$1/user.js"
    [[ -f "$file" ]] || return 0
    _zen_userjs_strip "$file" | _zen_write "$file"
    grep -q '[^[:space:]]' "$file" || rm -f "$file"
}

_zen_apply_one() {
    local dir="$1" vars="$2" sel="$3"
    mkdir -p "$dir/chrome" || return 1
    {
        printf '/* Generated by lyne zen apply from %s - edits are lost */\n\n' "$ZEN_TEMPLATES/userChrome.css"
        printf ':root {\n%s\n}\n\n%s {\n' "$vars" "$sel"
        cat "$ZEN_TEMPLATES/userChrome.css"
        printf '}\n'
        # Workspaces that keep their own gradient: Zen's transparency paints
        # only the gradient (its own opacity, often 0.35), so the window
        # gets the theme background underneath; the gradient tints it
        if [[ "$sel" != ":root" ]]; then
            printf '\n:root:not([zen-default-theme="true"]) {\n  background-color: var(--lyne-window) !important;\n}\n'
        fi
        # Zen paints unfocused windows with the opaque InactiveCaption
        # ("grey out inactive windows"), which hid the transparency
        printf '\n#zen-main-app-wrapper:-moz-window-inactive {\n  background: var(--zen-themed-toolbar-bg-transparent) !important;\n}\n' 
    } | _zen_write "$dir/chrome/lyne.css" || return 1
    {
        printf '/* Generated by lyne zen apply from %s - edits are lost */\n\n' "$ZEN_TEMPLATES/userContent.css"
        printf '@-moz-document url-prefix("about:") {\n:root {\n%s\n' "$vars"
        cat "$ZEN_TEMPLATES/userContent.css"
        printf '}\n}\n'
    } | _zen_write "$dir/chrome/lyne-content.css" || return 1
    _zen_userjs_write "$dir"
}

zen_apply() {
    local vars sel dir
    vars=$(_zen_vars) || return 1
    if [[ "$(_zen_option themeBackground true)" == true ]]; then
        sel=":root"
    else
        sel=':root[zen-default-theme="true"]'
    fi
    if [[ -n "${1:-}" ]]; then
        _zen_apply_one "$1" "$vars" "$sel"
        return
    fi
    local _r _n _d
    while IFS=$'\t' read -r _r _n dir _d; do
        zen_enabled "$dir" && { _zen_apply_one "$dir" "$vars" "$sel" || return 1; }
    done < <(zen_profiles)
    return 0
}

zen_enable() {
    local dir="$1"
    [[ -d "$dir" ]] || { echo "No profile at $dir" >&2; return 1; }
    zen_apply "$dir" || return 1
    _zen_add_import "$dir/chrome/userChrome.css" lyne.css &&
        _zen_add_import "$dir/chrome/userContent.css" lyne-content.css
}

zen_disable() {
    local dir="$1"
    [[ -d "$dir" ]] || { echo "No profile at $dir" >&2; return 1; }
    _zen_remove_import "$dir/chrome/userChrome.css"
    _zen_remove_import "$dir/chrome/userContent.css"
    rm -f "$dir/chrome/lyne.css" "$dir/chrome/lyne-content.css"
    rmdir "$dir/chrome" 2>/dev/null
    _zen_userjs_remove "$dir"
    # user.js values stay in prefs.js: turn transparency back off (Zen
    # rewrites prefs.js on exit, so only while it's closed)
    if ! zen_running "$dir" && [[ -f "$dir/prefs.js" ]]; then
        grep -vF 'user_pref("zen.widget.linux.transparency", true);' "$dir/prefs.js" | _zen_write "$dir/prefs.js"
    fi
    return 0
}
