# ~/.zshenv — environment for every zsh (login, interactive, scripts)
typeset -U path
# mise shims: tools installed with `mise use -g` work in scripts and GUI apps too
path=(~/.local/bin ~/.local/share/mise/shims $path)

export EDITOR=nvim            # terminal editor: git commits, sudoedit, crontab, …
export VISUAL="zed --wait"    # graphical editor: apps that prefer $VISUAL
export SUDO_EDITOR=nvim
export MANPAGER="nvim +Man!"
export BAT_THEME="Catppuccin Mocha"
