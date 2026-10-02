# lyne welcome - Open the welcome screen

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    echo "Usage: lyne welcome"
    echo ""
    echo "Open the welcome screen: the first choices and the main shortcuts."
    echo "It opens by itself on the first login after the install; Settings ›"
    echo "About opens it too."
    return 0
fi

if ! qs ipc call welcome open 2>/dev/null; then
    echo "lyne welcome: Quickshell isn't running (start it with: lyne reload)"
    return 1
fi
