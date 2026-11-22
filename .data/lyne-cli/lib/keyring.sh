#!/bin/bash
# =============================================================================
# keyring.sh - Unlock the keyring with the password the lock screen takes
#
# The lock screen (LockService) checks the password with PAM's "login" service.
# Its session has no gnome-keyring module, so a keyring locked again (after a
# suspend, or with autologin off) stays locked after a right password. The
# lines below add the module to that service, the way sddm does for the login
# screen. They're optional (a "-" prefix): a missing module never blocks login.
#
#   keyring_pam_status      "ok" (lines present), "missing" or "absent"
#                           (no gnome-keyring module installed)
#   keyring_pam_apply       writes the lines (sudo), keeping a backup once
#
# KEYRING_PAM_FILE and KEYRING_MODULE point it at test files.

KEYRING_PAM_FILE="${LYNE_KEYRING_PAM_FILE:-/etc/pam.d/login}"
KEYRING_MODULE="${LYNE_KEYRING_MODULE:-/usr/lib/security/pam_gnome_keyring.so}"
KEYRING_PAM_MARK="# lyne: unlock the keyring with the login password (lock screen too)"

keyring_pam_status() {
    [[ -f "$KEYRING_MODULE" ]] || { echo absent; return; }
    if grep -qxF "$KEYRING_PAM_MARK" "$KEYRING_PAM_FILE" 2>/dev/null; then
        echo ok
    else
        echo missing
    fi
}

keyring_pam_apply() {
    [[ "$(keyring_pam_status)" == missing ]] || return 0
    sudo cp -an "$KEYRING_PAM_FILE" "$KEYRING_PAM_FILE.lyne-bak" || return 1
    sudo sh -c "cat >> '$KEYRING_PAM_FILE'" <<EOF

$KEYRING_PAM_MARK
-auth       optional    pam_gnome_keyring.so
-password   optional    pam_gnome_keyring.so
-session    optional    pam_gnome_keyring.so auto_start
EOF
}
