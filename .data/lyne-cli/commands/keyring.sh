# lyne keyring - Unlock the keyring when the lock screen is unlocked

local subcmd="${1:-status}"

source "$DOTS_DIR/.data/lyne-cli/lib/keyring.sh"

case "$subcmd" in
    -h|--help)
        echo "Usage: lyne keyring [status|apply]"
        echo ""
        echo "The lock screen unlocks the keyring too, with the login password. This"
        echo "adds the gnome-keyring PAM lines to /etc/pam.d/login (sudo, once; the"
        echo "original is kept as login.lyne-bak)."
        echo ""
        echo "Subcommands:"
        echo "  status   Whether the lines are in place (default)"
        echo "  apply    Add them (sudo)"
        ;;
    status)
        case "$(keyring_pam_status)" in
            ok) echo "Keyring unlock on the lock screen: on" ;;
            missing) echo "Keyring unlock on the lock screen: off (run: lyne keyring apply)" ;;
            absent) echo "gnome-keyring isn't installed: nothing to unlock" ;;
        esac
        ;;
    apply)
        case "$(keyring_pam_status)" in
            absent) echo "gnome-keyring isn't installed: nothing to unlock" ;;
            ok) echo "Already set up" ;;
            missing) keyring_pam_apply && echo "Keyring unlock on the lock screen: on" ;;
        esac
        ;;
    *)
        echo "Unknown subcommand: $subcmd" >&2
        echo "Usage: lyne keyring [status|apply]" >&2
        return 1
        ;;
esac
