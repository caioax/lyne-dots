# lyne sddm - The login screen (lyne-sddm) following the shell theme

local subcmd="${1:-status}"

source "$DOTS_DIR/.data/lyne-cli/lib/sddm.sh"

case "$subcmd" in
    -h|--help)
        echo "Usage: lyne sddm [status|apply]"
        echo ""
        echo "With the lyne-sddm theme installed, the login screen follows the shell:"
        echo "its palette, background opacity, wallpaper and profile picture are copied"
        echo "to $SDDM_DIR (the greeter can't read your home), which lyne-sddm creates."
        echo "The shell syncs on every change; it shows on the next login. Turn it off"
        echo "in Settings > Theme > Login screen."
        echo ""
        echo "Subcommands:"
        echo "  status   Whether the theme is installed, selected and synced (default)"
        echo "  apply    Sync now (with the option off: back to the theme's defaults)"
        ;;
    status)
        sddm_problem || return 0
        local sync
        sync=$(_sddm_option sync .sddm.sync)
        echo "  Theme     $SDDM_THEME"
        echo "  Selected  $(sddm_active && echo yes || echo "no (run lyne-sddm to select it)")"
        echo "  Files     $SDDM_DIR"
        echo "  Sync      $([[ "$sync" == "false" ]] && echo "off (theme defaults)" || echo on)"
        local conf="$SDDM_DIR/theme.conf.user" f
        if [[ -f "$conf" ]] && grep -q '^accent=' "$conf"; then
            echo "  Synced    $(date -r "$conf" '+%Y-%m-%d %H:%M')"
            for f in "$SDDM_DIR"/wallpaper.* "$SDDM_AVATAR"; do
                [[ -f "$f" ]] && echo "            ${f#"$SDDM_DIR"/}"
            done
        fi
        ;;
    apply)
        sddm_problem || return 1
        sddm_apply && echo "Login screen synced (shows on the next login)"
        ;;
    *)
        echo "lyne sddm: unknown subcommand '$subcmd' (see lyne sddm --help)"
        return 1
        ;;
esac
