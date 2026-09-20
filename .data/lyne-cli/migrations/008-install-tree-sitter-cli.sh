# 008-install-tree-sitter-cli.sh - Install tree-sitter-cli
#
# nvim-treesitter now shells out to the `tree-sitter` CLI binary to build
# parsers ("tree-sitter build"). The `tree-sitter` pacman package only ships
# the runtime library, not the CLI, so this installs the missing package
# for existing users.

if ! command -v tree-sitter &>/dev/null; then
    if command -v pacman &>/dev/null; then
        echo "   Installing tree-sitter-cli..."
        sudo pacman -S --needed --noconfirm tree-sitter-cli
    else
        echo "   tree-sitter-cli not found. Please install it manually."
    fi
else
    echo "   tree-sitter already installed, skipping"
fi
