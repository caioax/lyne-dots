# lyne sddm - The login screen (lyne-sddm) following the shell theme

local subcmd="${1:-status}"

source "$DOTS_DIR/.data/lyne-cli/lib/sddm.sh"

case "$subcmd" in
    -h|--help)
        echo "Usage: lyne sddm [status|apply]"
        echo ""
        echo "With the lyne-sddm theme installed, the login screen follows the shell:"
        echo "its palette, background opacity, wallpaper and profile picture are copied"
        echo "to $SDDM_USER_DIR (the greeter can't read your home)."
        echo "The shell syncs on every change; it shows on the next login. Turn it off"
        echo "in Settings > Theme > Login screen."
        echo ""
        echo "Subcommands:"
        echo "  status   Whether the theme is installed, selected and synced (default)"
        echo "  apply    Sync now (with the option off: back to the theme's defaults)"
        ;;
    status)
        if ! sddm_installed; then
            echo "lyne-sddm isn't installed (no writable $SDDM_USER_DIR)"
            return 0
        fi
        local sync
        sync=$(_sddm_option sync .sddm.sync)
        echo "  Theme     $SDDM_THEME"
        echo "  Selected  $(sddm_active && echo yes || echo "no (run lyne-sddm to select it)")"
        echo "  Sync      $([[ "$sync" == "false" ]] && echo "off (theme defaults)" || echo on)"
        local conf="$SDDM_USER_DIR/theme.conf.user" f
        if [[ -f "$conf" ]] && grep -q '^accent=' "$conf"; then
            echo "  Synced    $(date -r "$conf" '+%Y-%m-%d %H:%M')"
            for f in "$SDDM_USER_DIR"/wallpaper.* "$SDDM_AVATAR"; do
                [[ -f "$f" ]] && echo "            ${f#"$SDDM_THEME"/}"
            done
        fi
        ;;
    apply)
        sddm_installed || { echo "lyne-sddm isn't installed (no writable $SDDM_USER_DIR)"; return 1; }
        sddm_apply && echo "Login screen synced (shows on the next login)"
        ;;
    *)
        echo "lyne sddm: unknown subcommand '$subcmd' (see lyne sddm --help)"
        return 1
        ;;
esac
