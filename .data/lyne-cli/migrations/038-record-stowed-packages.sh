# 038-record-stowed-packages.sh - Which dotfiles packages are linked
#
# The installer now links only the packages of the categories chosen and
# keeps the list in state.json (.system.stow), read by lyne update,
# ./install.sh --stow-only and lyne link. Older installs linked every package:
# the ones HOME reaches through links today are recorded, nothing is unlinked.

source "$DOTS_DIR/.install/setup/stow.sh"

if [[ ! -f "$(lyne_state_file)" ]]; then
    echo "   state.json not found, skipping"
    return 0
fi
if [[ "$(jq -r '.system.stow | type' "$(lyne_state_file)")" == array ]]; then
    return 0
fi

mapfile -t packages < <(stow_linked_packages)
stow_record "${packages[@]}" || {
    echo "   Error: could not write state.json"
    return 1
}
echo "   Linked packages: ${packages[*]:-none}"
