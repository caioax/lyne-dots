# 051-lock-keyring-hint.sh - Point users to lyne keyring
#
# The lock screen can unlock the keyring with the login password now. It needs
# lines in /etc/pam.d/login (sudo), so existing installs only get a hint, once.
# Nothing is changed here. Where gnome-keyring isn't installed, it says nothing.

source "$DOTS_DIR/.data/lyne-cli/lib/keyring.sh"

if [[ "$(keyring_pam_status)" == missing ]]; then
    echo "   New: the lock screen can unlock the keyring too."
    echo "   Turn it on with: lyne keyring apply"
fi
true
