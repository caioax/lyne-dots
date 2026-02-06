# === VISUAL FETCH ===
# Running before P10k instant prompt to prevent warnings
# if [[ $(pgrep -cx kitty) -le 1 ]] && command -v fastfetch >/dev/null 2>&1; then
  echo -e "\e[1;34m"
  echo "  █   █▄█ █▄ █ █▀▀"
  echo "  █▄▄  █  █ ▀█ ██▄"
  echo -e "\e[0m"
  fastfetch
# fi

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
[[ -n $SSH_CONNECTION ]] && export EDITOR='vim' || export EDITOR='nvim'
export PATH="$HOME/.local/bin:$PATH"
export PATH="$PATH:$HOME/.spicetify"

# === CUSTOM FUNCTIONS & VI-MODE FIXES ===
function zvm_vi_yank() {
    zvm_yank
    echo -n "${CUTBUFFER}" | wl-copy
}

ZVM_CURSOR_STYLE_ENABLED=true
autoload -U edit-command-line
zle -N edit-command-line

function zvm_after_init() {
  zvm_bindkey vicmd '^V' edit-command-line
  zvm_bindkey viins '^V' edit-command-line
}

# === LYNE CLI ===
lyne() {
    local DOTS_DIR="$HOME/.lyne-dots"
    local CMD_DIR="$DOTS_DIR/.data/lyne-cli/commands"

    local cmd="${1:-help}"
    shift 2>/dev/null

    local cmd_file="$CMD_DIR/$cmd.sh"
    if [[ -f "$cmd_file" ]]; then
        source "$cmd_file" "$@"
    else
        echo "lyne: unknown command '$cmd'"
        echo "Available commands:"
        for f in "$CMD_DIR"/*.sh; do
            echo "  $(basename "${f%.sh}")"
        done
    fi
}

# === ALIASES ===
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
