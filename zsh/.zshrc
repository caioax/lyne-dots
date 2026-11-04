# === VISUAL FETCH ===
# Running before P10k instant prompt to prevent warnings. Only in a new
# terminal: not in tmux panes and popups, Neovim's :terminal or nested shells
if [[ -z $TMUX && -z $NVIM && $SHLVL -le 1 ]] && command -v fastfetch >/dev/null 2>&1; then
  echo -e "\e[1;34m"
  echo "  █   █▄█ █▄ █ █▀▀"
  echo "  █▄▄  █  █ ▀█ ██▄"
  echo -e "\e[0m"
  fastfetch
fi

# Nested shells and reloads would add the same PATH entries again
typeset -U path

# === POWERLEVEL10K INSTANT PROMPT ===
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# === POWERLEVEL10K CONFIGURATION ===
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# === OH MY ZSH CONFIGURATION ===
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
ZSH_TMUX_AUTOSTART=false
ZSH_TMUX_AUTOCONNECT=false
ZSH_TMUX_DEFAULT_SESSION_NAME="main"
ZSH_TMUX_UNICODE=true

plugins=(
  git 
  zsh-autosuggestions 
  zsh-syntax-highlighting 
  zsh-vi-mode
)

source $ZSH/oh-my-zsh.sh

# === ENVIRONMENT VARIABLES ===
# Editor chosen in Settings > System > Apps (vim over SSH)
if [[ -n $SSH_CONNECTION ]]; then
    export EDITOR='vim'
else
    export EDITOR="$(jq -r '.system.editor // empty' ~/.config/quickshell/state.json 2>/dev/null)"
    [[ -z $EDITOR ]] && export EDITOR='nvim'
fi
# Through the array: typeset -U path dedupes it (an export PATH=... doesn't)
path=("$HOME/.local/bin" $path "$HOME/.spicetify")

# === CUSTOM FUNCTIONS & VI-MODE FIXES ===
function zvm_vi_yank() {
    zvm_yank
    echo -n "${CUTBUFFER}" | wl-copy
    zvm_exit_visual_mode
}

ZVM_CURSOR_STYLE_ENABLED=true
autoload -U edit-command-line
zle -N edit-command-line

function zvm_after_init() {
  zvm_bindkey vicmd '^V' edit-command-line
  zvm_bindkey viins '^V' edit-command-line
}

# tmux redraws its status every 15 s: show the new path right away on cd
if [[ -n $TMUX ]]; then
    _tmux_status_refresh() { tmux refresh-client -S 2>/dev/null }
    chpwd_functions+=(_tmux_status_refresh)
fi

# === TMUX: the tm commands ===
# tm      the project's session, or main anywhere else (plain tmux does too)
# tmn     a new session, named           tmq  close a session (this one)
# tmk     close every session; prefix + C-r in the next tmux brings back the
#         last save (tmux-resurrect)     tmkf the same, and forget that save
#
# tmux with no arguments, outside tmux: in a project (the nearest folder
# with project.godot, a *.sln, .git or .root) that project's session, made
# in its folder when there's none, named as prefix + P names it; anywhere
# else the session main (made in ~), so plain tmux never makes numbered
# sessions. With arguments, or inside tmux, tmux as it is
tmux() {
    if (( $# == 0 )) && [[ -z $TMUX ]] && (( $+commands[nvim] )); then
        local cli="${LYNE_DOTS:-$HOME/.lyne-dots}/nvim/.config/nvim/local-plugins/project-instance.nvim/lua/project_instance/cli.lua"
        local root session socket alive found
        if [[ -f $cli ]] && IFS=$'\t' read -r root session socket alive found < <(nvim --clean --headless -l "$cli" locate 2>/dev/null) && [[ $found == 1 ]]; then
            command tmux new-session -A -s "$session" -c "$root"
            return
        fi
    fi
    if (( $# == 0 )) && [[ -z $TMUX ]]; then
        command tmux new-session -A -s main -c ~
        return
    fi
    command tmux "$@"
}
tm() { tmux "$@"; }
# tmn <name> [folder]: a new session on purpose (prefix + C does it inside
# tmux), in the folder or the current one; one with that name already there
# is just entered. The name is required: no numbered sessions
tmn() {
    if [[ -z $1 ]]; then
        print -u2 "usage: tmn <name> [folder]"
        return 1
    fi
    # tmux turns "." and ":" into "_" itself; =name must find it after
    local name="${1//[.:]/_}" dir="${2:-$PWD}"
    if [[ -z $TMUX ]]; then
        command tmux new-session -A -s "$name" -c "$dir"
        return
    fi
    command tmux has-session -t "=$name" 2>/dev/null ||
        command tmux new-session -d -s "$name" -c "$dir" || return
    command tmux switch-client -t "=$name"
}
# tmq [name]: close a session, this one with no name (the terminal goes to
# the one used last, tmux.conf's detach-on-destroy off)
tmq() {
    if [[ -n $1 ]]; then
        command tmux kill-session -t "=${1//[.:]/_}"
    elif [[ -n $TMUX ]]; then
        command tmux kill-session
    else
        print -u2 "usage: tmq [name]   (no name: the session you're in, inside tmux)"
        return 1
    fi
}
tmk() { command tmux kill-server; }
tmkf() {
    local last
    last="$(bash -c 'source ~/.tmux/plugins/tmux-resurrect/scripts/helpers.sh && last_resurrect_file' 2>/dev/null)"
    command tmux kill-server 2>/dev/null
    [[ -n "$last" ]] && rm -f "$last"
}

# === UPDATES ===
all-update() {
    local STATE_FILE="$HOME/.config/quickshell/state.json"
    local AUR_HELPER="yay"

    if command -v jq &>/dev/null && [[ -f "$STATE_FILE" ]]; then
        local HELPER
        HELPER=$(jq -r '.system.aurHelper // "yay"' "$STATE_FILE")
        [[ -n "$HELPER" && "$HELPER" != "null" ]] && AUR_HELPER="$HELPER"
    fi

    echo -e "\e[1;34m:: Updating system packages (pacman)...\e[0m"
    sudo pacman -Syu

    echo -e "\e[1;34m:: Updating AUR packages ($AUR_HELPER)...\e[0m"
    $AUR_HELPER -Syu

    if command -v flatpak &>/dev/null; then
        echo -e "\e[1;34m:: Updating Flatpak packages...\e[0m"
        flatpak update
    fi

    echo -e "\e[1;32m:: All updates complete!\e[0m"
}

export NVM_DIR="$HOME/.config/nvm"
# if, not &&: without nvm a false test would be the shell's last status, so
# `exit` as the first command would end it with 1 (Neovim's terminal reports
# that as an error)
if [[ -s "$NVM_DIR/nvm.sh" ]]; then . "$NVM_DIR/nvm.sh"; fi
if [[ -s "$NVM_DIR/bash_completion" ]]; then . "$NVM_DIR/bash_completion"; fi
