# 040-cpprun-out.sh - cpprun left lyne-dots
#
# cpprun (compile and run a C++ file) has a repo of its own now, with its own
# install script. The link stow left in ~/.local/bin points at a file that's
# gone: it's removed. A cpprun installed from anywhere else stays.

link="$HOME/.local/bin/cpprun"
if [[ -L "$link" && ! -e "$link" &&
    "$(realpath -m "$link")" == "$(realpath -m "$DOTS_DIR/local/.local/bin/cpprun")" ]]; then
    rm "$link"
    echo "   Removed ~/.local/bin/cpprun: cpprun has a repo of its own now"
fi
