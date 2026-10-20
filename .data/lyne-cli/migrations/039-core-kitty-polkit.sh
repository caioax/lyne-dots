# 039-core-kitty-polkit.sh - Polkit agent and the default terminal in core
#
# The autostart starts polkit-kde-agent (password prompts), but it came with
# the optional utils packages; core installed hyprpolkitagent instead, which
# nothing starts. Kitty, the default terminal, came with the terminal
# category. Both are in core now: installed when missing (kitty only while it
# is still the default terminal). hyprpolkitagent stays installed.

if command -v pacman &>/dev/null; then
    terminal="$(jq -r '.apps.terminal.command // "kitty"' "$(lyne_state_file)" 2>/dev/null)"
    wanted=(polkit-kde-agent)
    [[ "${terminal:-kitty}" == kitty ]] && wanted+=(kitty)

    missing=()
    for pkg in "${wanted[@]}"; do
        pacman -Q "$pkg" &>/dev/null || missing+=("$pkg")
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "   Installing ${missing[*]}..."
        sudo pacman -S --needed --noconfirm "${missing[@]}"
    else
        echo "   ${wanted[*]} already installed, skipping"
    fi
else
    [[ -x /usr/lib/polkit-kde-authentication-agent-1 ]] ||
        echo "   polkit-kde-agent not found. Please install it manually (password prompts need it)."
fi
