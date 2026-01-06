# === POWERLEVEL10K INSTANT PROMPT ===
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# === OMZ CONFIGURATION ===
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

# --- Tmux Plugin Settings ---
ZSH_TMUX_AUTOSTART=true
ZSH_TMUX_AUTOCONNECT=true
ZSH_TMUX_DEFAULT_SESSION_NAME="main"
ZSH_TMUX_UNICODE=true

# --- Plugins List ---
plugins=(git zsh-autosuggestions zsh-vi-mode zsh-syntax-highlighting tmux)

source $ZSH/oh-my-zsh.sh

# === EDITOR SETTINGS ===
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='nvim'
fi

# === CUSTOM FIXES & INTEGRATIONS ===

# 1. Clipboard Fix (Tmux + Hyprland + Zsh-Vi-Mode)
function zvm_vi_yank() {
    zvm_yank
    echo -n "${CUTBUFFER}" | wl-copy
}

# 2. Zsh Vi Mode Custom Logic (Command Mode Emulation)
ZVM_CURSOR_STYLE_ENABLED=true
autoload -U edit-command-line
zle -N edit-command-line

typeset -g IN_CMD_MODE=0
typeset -g HAS_STASHED=0

function toggle-cmd-mode() {
  # Sair/Cancelar
  if [[ "$IN_CMD_MODE" -eq 1 ]]; then
    IN_CMD_MODE=0
    BUFFER="" 
    if [[ "$HAS_STASHED" -eq 1 ]]; then
       zle .get-line
    fi
    RPROMPT=""
    zle reset-prompt
    zle -U "a"
    return
  fi

  # Entrar
  IN_CMD_MODE=1
  HAS_STASHED=0
  if [[ -n "$BUFFER" ]]; then
    zle push-line
    HAS_STASHED=1
  fi
  BUFFER=""
  RPROMPT="%B%F{cyan}COMMAND%f%b"
  zle reset-prompt
  zle -U "i"
}
zle -N toggle-cmd-mode

function execute-cmd-mode() {
  if [[ "$IN_CMD_MODE" -eq 1 ]]; then
    IN_CMD_MODE=0
    RPROMPT=""
    zle reset-prompt
  fi
  zle .accept-line
}
zle -N execute-cmd-mode

function zvm_after_init() {
  zvm_bindkey vicmd '^V' edit-command-line
  zvm_bindkey viins '^V' edit-command-line
  zvm_bindkey vicmd ':' toggle-cmd-mode
  zvm_bindkey viins '^M' execute-cmd-mode
  zvm_bindkey vicmd '^M' execute-cmd-mode
}

# === ALIASES ===
alias all-update='sudo pacman -Syu && yay -Syu && flatpak update'

# Dotfiles Management
alias dots='git -C ~/.arch-dots'

# === FUNCTIONS ===

# Dots Save Helper
function dots-save() {
    local GREEN='\033[1;32m'
    local BLUE='\033[1;34m'
    local YELLOW='\033[1;33m'
    local RED='\033[0;31m'
    local NC='\033[0m' 

    if [ -z "$1" ]; then
        echo "${RED} Error: You must provide a commit message.${NC}"
        echo "   Usage: dots-save \"Your message here\""
        return 1
    fi

    local DOTS_DIR="$HOME/.arch-dots"

    echo ""
    echo "${BLUE}󰏔  Starting DOTFILES synchronization...${NC}"
    echo "----------------------------------------"
    echo "${YELLOW}1. Checking changes and staging files...${NC}"
    
    if [[ -n $(git -C "$DOTS_DIR" status --porcelain) ]]; then
        git -C "$DOTS_DIR" status --short | sed 's/^/   /' 
        git -C "$DOTS_DIR" add .
        echo "${GREEN}    Files staged successfully.${NC}"
    else
        echo "${GREEN}    Directory clean (no new changes found).${NC}"
    fi

    if ! git -C "$DOTS_DIR" diff --cached --quiet; then
        echo ""
        echo "${YELLOW}2. Creating commit...${NC}"
        git -C "$DOTS_DIR" commit -m "$1" | sed 's/^/   /' 
        echo "${GREEN}    Commit created: '$1'${NC}"
    else
        echo ""
        echo "${YELLOW}2. Skipping commit (nothing new to commit).${NC}"
    fi

    echo ""
    echo "${YELLOW}3. Pushing to remote repository...${NC}"
    if git -C "$DOTS_DIR" push; then
        echo ""
        echo "----------------------------------------"
        echo "${GREEN}󰄬 SUCCESS! Dotfiles are synced and secure.${NC}"
        echo ""
    else
        echo ""
        echo "${RED} FAILED to push. Check network or conflicts.${NC}"
        return 1
    fi
}

# === FINALIZERS ===
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
export PATH=$PATH:/home/caio/.spicetify
