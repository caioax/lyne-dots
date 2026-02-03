# === VISUAL FETCH ===
# Running before P10k instant prompt to prevent warnings
if [[ $(pgrep -cx kitty) -le 1 ]] && command -v fastfetch >/dev/null 2>&1; then
  fastfetch
fi

# === POWERLEVEL10K INSTANT PROMPT ===
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# === POWERLEVEL10K CONFIGURATION ===
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# === AUTO-INSTALLATION LOGIC (PORTABLE) ===
export ZSH="$HOME/.oh-my-zsh"

SETUP_NEEDED=false

if [[ ! -d "$ZSH" ]]; then
  git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$ZSH" >/dev/null 2>&1
  SETUP_NEEDED=true
fi

ZSH_CUSTOM_DIR="$ZSH/custom"
DEPENDENCIES=(
  "https://github.com/zsh-users/zsh-autosuggestions|plugins/zsh-autosuggestions"
  "https://github.com/zsh-users/zsh-syntax-highlighting|plugins/zsh-syntax-highlighting"
  "https://github.com/jeffreytse/zsh-vi-mode|plugins/zsh-vi-mode"
  "https://github.com/romkatv/powerlevel10k|themes/powerlevel10k"
)

for item in "${DEPENDENCIES[@]}"; do
  URL="${item%%|*}"
  DEST="${item##*|}"
  if [[ ! -d "$ZSH_CUSTOM_DIR/$DEST" ]]; then
    git clone --depth=1 "$URL" "$ZSH_CUSTOM_DIR/$DEST" >/dev/null 2>&1
    SETUP_NEEDED=true
  fi
done

# Display setup instructions if anything was installed
if [[ "$SETUP_NEEDED" = true ]]; then
  echo ""
  echo "╔════════════════════════════════════════════════════════════╗"
  echo "║  🎉 ZSH Setup Complete!                                   ║"
  echo "╠════════════════════════════════════════════════════════════╣"
  echo "║  To make ZSH your default shell, run:                     ║"
  echo "║  → chsh -s \$(which zsh)                                   ║"
  echo "║                                                            ║"
  echo "║  Then log out and log back in for changes to take effect. ║"
  echo "║                                                            ║"
  echo "║  To configure Powerlevel10k theme, run:                   ║"
  echo "║  → p10k configure                                         ║"
  echo "╚════════════════════════════════════════════════════════════╝"
  echo ""
fi

# === OH MY ZSH CONFIGURATION ===
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
alias all-update='sudo pacman -Syu; yay -Syu; flatpak update'
