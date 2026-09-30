#!/bin/bash
# =============================================================================
# log.sh - Messages of the install and setup scripts
# =============================================================================
# Colored on a terminal, plain text when the installer sends them to its log
# file. Usage: source this file
# =============================================================================

_log() {
    local color=$1 tag=$2 text=$3
    if [[ -t 1 ]]; then
        printf '\033[%sm%s\033[0m %s\n' "$color" "$tag" "$text"
    else
        printf '%s %s\n' "$tag" "$text"
    fi
}

log_info() { _log "0;32" "[INFO]" "$1"; }
log_warn() { _log "1;33" "[WARN]" "$1"; }
log_error() { _log "0;31" "[ERROR]" "$1"; }
log_step() { _log "0;36" "[>>]" "$1"; }
log_question() { _log "0;34" "[?]" "$1"; }

log_header() {
    local rule="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if [[ -t 1 ]]; then
        printf '\n\033[0;34m%s\n  %s\n%s\033[0m\n\n' "$rule" "$1" "$rule"
    else
        printf '\n== %s ==\n\n' "$1"
    fi
}
