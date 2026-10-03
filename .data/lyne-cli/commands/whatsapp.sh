# lyne whatsapp - WhatsApp Web as a Chromium app (the WhatsApp special workspace)

local web_dir="$DOTS_DIR/.data/whatsapp"
local profile="$HOME/.local/share/lyne/whatsapp"
# From the "key" in extension/manifest.json
local extension_id="dnfagpefanlhiklbimaimnmcbeongeik"

case "${1:-}" in
    -h|--help)
        echo "Usage: lyne whatsapp [chromium options...]"
        echo ""
        echo "Opens WhatsApp Web as a Chromium app with its own profile"
        echo "(${profile/#$HOME/\~}), the app of the WhatsApp special workspace"
        echo "(SUPER+W). Links clicked in it open in the default browser."
        return 0
        ;;
esac

if ! command -v chromium &>/dev/null; then
    echo "lyne whatsapp: chromium isn't installed (sudo pacman -S chromium)" >&2
    notify-send -a "WhatsApp" -i whatsapp "Chromium isn't installed" "WhatsApp Web needs it: sudo pacman -S chromium" 2>/dev/null
    return 1
fi

# The extension's native host (opens links with xdg-open), looked up in the
# profile; rewritten on every start so it follows the dotfiles folder
mkdir -p "$profile/NativeMessagingHosts"
cat >"$profile/NativeMessagingHosts/lyne.open_link.json" <<EOF
{
    "name": "lyne.open_link",
    "description": "Opens WhatsApp Web links in the default browser",
    "path": "$web_dir/open-link.py",
    "type": "stdio",
    "allowed_origins": ["chrome-extension://$extension_id/"]
}
EOF

exec chromium --app=https://web.whatsapp.com --user-data-dir="$profile" \
    --load-extension="$web_dir/extension" --no-first-run --no-default-browser-check "$@"
