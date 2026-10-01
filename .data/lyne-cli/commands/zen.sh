# lyne zen - The lyne theme in Zen Browser profiles

local subcmd="${1:-status}"

source "$DOTS_DIR/.data/lyne-cli/lib/zen.sh"

# A profile by folder or by name (as in about:profiles)
_zen_resolve() {
    local want="$1" root name dir def
    [[ -d "$want" ]] && { realpath "$want"; return 0; }
    while IFS=$'\t' read -r root name dir def; do
        [[ "$name" == "$want" ]] && { echo "$dir"; return 0; }
    done < <(zen_profiles)
    echo "No Zen profile named or at '$want' (see lyne zen status)" >&2
    return 1
}

case "$subcmd" in
    -h|--help)
        echo "Usage: lyne zen [status|--json|apply|enable <profile>|disable <profile>]"
        echo ""
        echo "Zen Browser follows the shell theme in the profiles where it's enabled:"
        echo "lyne-dots adds an @import line to the profile's chrome/userChrome.css and"
        echo "userContent.css (the files you had are kept, with a .lyne-bak copy) and"
        echo "a marked block to user.js. Zen reads them at startup, so a running Zen"
        echo "shows a new theme after a restart. Options live in Settings > Theme."
        echo ""
        echo "Subcommands:"
        echo "  status             Profiles and whether they follow the theme (default)"
        echo "  --json             The profiles as JSON"
        echo "  apply              Rewrite the theme in every enabled profile"
        echo "  enable <profile>   Follow the theme (profile name or folder)"
        echo "  disable <profile>  Stop following it and remove the lyne files"
        ;;
    status)
        local root name dir def any=false
        while IFS=$'\t' read -r root name dir def; do
            any=true
            local flags=()
            [[ $def == 1 ]] && flags+=("default")
            zen_running "$dir" && flags+=("open")
            printf '  %s %-20s %s%s\n' \
                "$(zen_enabled "$dir" && echo "●" || echo "○")" "$name" "${dir/#$HOME/\~}" \
                "$( ((${#flags[@]})) && echo " (${flags[*]})")"
        done < <(zen_profiles)
        if [[ $any == false ]]; then
            echo "No Zen Browser profiles found"
        else
            echo ""
            echo "● follows the lyne theme   ○ doesn't (lyne zen enable <profile>)"
        fi
        ;;
    --json)
        zen_json
        ;;
    apply)
        zen_apply
        ;;
    enable|disable)
        [[ -n "${2:-}" ]] || { echo "Usage: lyne zen $subcmd <profile>"; return 1; }
        local target
        target=$(_zen_resolve "$2") || return 1
        "zen_$subcmd" "$target" || return 1
        if zen_running "$target"; then
            echo "Done. Restart Zen to see it."
        else
            echo "Done."
        fi
        ;;
    *)
        echo "Unknown subcommand: $subcmd"
        echo "Run 'lyne zen --help' for usage."
        return 1
        ;;
esac
