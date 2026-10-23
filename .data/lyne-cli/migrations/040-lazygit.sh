# 040-lazygit.sh - lazygit with the editor packages
#
# Neovim's <leader>lg / <leader>gl (Snacks' lazygit) and tmux's prefix + G
# open lazygit, which no package list installed. It comes with the editor
# category now: installed when Neovim is (that category's main package) and
# lazygit is missing.

if command -v pacman &>/dev/null; then
    if pacman -Q neovim &>/dev/null; then
        if pacman -Q lazygit &>/dev/null; then
            echo "   lazygit already installed, skipping"
        else
            echo "   Installing lazygit..."
            sudo pacman -S --needed --noconfirm lazygit
        fi
    fi
elif command -v nvim &>/dev/null && ! command -v lazygit &>/dev/null; then
    echo "   lazygit not found. Please install it manually (Neovim's <leader>lg and tmux's prefix + G open it)."
fi
