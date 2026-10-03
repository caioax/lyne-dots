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

# Chromium keeps running the first service worker it saw for an extension
# loaded from the command line, even after its files change: the copy in the
# profile names it after its content, so a new version gets a new script
local extension="$profile/lyne-extension"
local sw="background-$(sha1sum "$web_dir/extension/background.js" | cut -c1-12).js"
rm -rf "$extension.new"
mkdir -p "$extension.new"
cp "$web_dir/extension/"*.js "$extension.new/"
mv "$extension.new/background.js" "$extension.new/$sw"
sed "s/\"background\.js\"/\"$sw\"/" "$web_dir/extension/manifest.json" >"$extension.new/manifest.json"
# Left alone when nothing changed (WhatsApp may be running from it)
if diff -rq "$extension.new" "$extension" &>/dev/null; then
    rm -rf "$extension.new"
else
    rm -rf "$extension"
    mv "$extension.new" "$extension"
fi

exec chromium --app=https://web.whatsapp.com --user-data-dir="$profile" \
    --load-extension="$extension" --no-first-run --no-default-browser-check "$@"
