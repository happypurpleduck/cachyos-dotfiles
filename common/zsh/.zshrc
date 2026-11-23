# ~/.zshrc — Oh My Zsh + Powerlevel10k on top of CachyOS's zsh config.
# Prompt colours follow the shell accent (~/.config/zsh/p10k-mocha.zsh, loaded by ~/.p10k.zsh).

# Oh My Zsh plugins (must be set before CachyOS's config loads Oh My Zsh)
plugins=(
  git                # git aliases (gst, gco, gl, …)
  sudo               # Esc Esc puts sudo in front of the last command
  extract            # `extract <archive>` for any format
  fzf                # Ctrl+R history, Ctrl+T files, Alt+C directories
  zoxide             # `z <part of a path>` jumps to frequent directories
  colored-man-pages
)

# Oh My Zsh's auto-correct prompt ("did you mean…") is more annoying than useful
ENABLE_CORRECTION="false"
# Updates come from pacman (oh-my-zsh-git), not Oh My Zsh's own updater
zstyle ':omz:update' mode disabled

# CachyOS base: Oh My Zsh, Powerlevel10k (+ instant prompt), autosuggestions,
# syntax highlighting, history substring search, pkgfile handler, aliases
source /usr/share/cachyos-zsh-config/cachyos-config.zsh

# ── History ─────────────────────────────────────────────────────────
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt EXTENDED_HISTORY HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE HIST_REDUCE_BLANKS SHARE_HISTORY INC_APPEND_HISTORY

# ── Completion ──────────────────────────────────────────────────────
zstyle ':completion:*' menu select                                   # arrow-key menu
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'   # case-insensitive, fuzzy-ish
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*:descriptions' format '%F{#6c7086}── %d ──%f'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' squeeze-slashes true
setopt AUTO_CD AUTO_PUSHD PUSHD_IGNORE_DUPS

# ── Autosuggestions / highlighting in Mocha ─────────────────────────
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#6c7086'
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
typeset -gA ZSH_HIGHLIGHT_STYLES
ZSH_HIGHLIGHT_STYLES[command]='fg=#a6e3a1'
ZSH_HIGHLIGHT_STYLES[builtin]='fg=#a6e3a1'
ZSH_HIGHLIGHT_STYLES[alias]='fg=#a6e3a1'
ZSH_HIGHLIGHT_STYLES[function]='fg=#a6e3a1'
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=#f38ba8'
ZSH_HIGHLIGHT_STYLES[reserved-word]='fg=#cba6f7'
ZSH_HIGHLIGHT_STYLES[path]='fg=#cdd6f4,underline'
ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=#f9e2af'
ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=#f9e2af'
ZSH_HIGHLIGHT_STYLES[commandseparator]='fg=#94e2d5'
ZSH_HIGHLIGHT_STYLES[comment]='fg=#6c7086'

# ── Keys ────────────────────────────────────────────────────────────
bindkey '^[[A' history-substring-search-up       # ↑ / ↓ search history by what you've typed
bindkey '^[[B' history-substring-search-down
bindkey '^[[1;5C' forward-word                   # Ctrl+→ / Ctrl+←
bindkey '^[[1;5D' backward-word
bindkey '^[[3~' delete-char
HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND='fg=#11111b,bg=#a6e3a1'
HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND='fg=#11111b,bg=#f38ba8'

# ── fzf in Mocha ────────────────────────────────────────────────────
export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_DEFAULT_OPTS="--height 40% --layout reverse --border rounded \
  --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8,fg:#cdd6f4,header:#f38ba8 \
  --color=info:#cba6f7,pointer:#f5e0dc,marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8 \
  --color=selected-bg:#45475a,border:#45475a,label:#cdd6f4"

# ── Aliases ─────────────────────────────────────────────────────────
alias ls='eza --icons=auto --group-directories-first'
alias ll='eza -l --icons=auto --group-directories-first --git'
alias la='eza -la --icons=auto --group-directories-first --git'
alias lt='eza --tree --level=2 --icons=auto'
alias cat='bat --paging=never --style=plain'
alias v='nvim'
alias lg='lazygit'
alias update='sudo pacman -Syu && paru -Sua'   # repos, then AUR packages

# ── mise (runtimes and global tools such as claude) ─────────────────
if [[ -x "$HOME/.local/bin/mise" ]]; then
  eval "$("$HOME/.local/bin/mise" activate zsh)"
elif (( $+commands[mise] )); then
  eval "$(mise activate zsh)"
fi
