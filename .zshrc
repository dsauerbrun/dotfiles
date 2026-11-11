export PATH="$HOME/.opencode/bin:$PATH"

export ZSH="${HOME}/.oh-my-zsh"

# theme
ZSH_THEME="apple"

# aliases
source $ZSH/oh-my-zsh.sh
source $HOME/.aliases

TERM=xterm-256color

# rex: rex-setup.sh is the one place that knows how the server starts (with
# --tailscale and this workspace's node name). A bare "rex server start" typed
# by hand goes through it, so it can't come up as Tailscale's default "rex".
# Anything else passes straight through.
rex() {
  if [[ $# -eq 2 && "$1" == server && "$2" == start && -x "$HOME/dotfiles/rex-setup.sh" ]]; then
    "$HOME/dotfiles/rex-setup.sh"
  else
    command rex "$@"
  fi
}

# rex on SSH login: start the server if none is running, otherwise show the
# Tailscale sign-in link when the server needs one.
# The dotfiles post-start hook also starts the server, but it runs after the
# rest of the workspace setup, which can take minutes after a power-on. Logging
# in first starts it the same way, and the hook's later start is a no-op.
# --autostart=false keeps a status check from launching a server without --tailscale.
if [[ -n "$SSH_CONNECTION" ]] && (( $+commands[rex] )); then
  if rex_status=$(command rex server status --autostart=false --timeout 2s 2>/dev/null); then
    rex_login_url=$(print -r -- "$rex_status" | sed -n 's/^  authenticate: //p')
    [[ -n "$rex_login_url" ]] && echo "rex: Tailscale sign-in needed: $rex_login_url"
  elif [[ -x "$HOME/dotfiles/rex-setup.sh" ]]; then
    echo "rex: no server running, starting one"
    "$HOME/dotfiles/rex-setup.sh"
  fi
  unset rex_status rex_login_url
fi

# rex sessions: the Mac app creates sessions without a working directory, so
# their shells start in $HOME. Start in the workspace instead. Splits and tabs
# that inherit a pane's directory are already elsewhere and are left alone.
if [[ "$TERM_PROGRAM" == rex && "$PWD" == "$HOME" && -d /workspaces/obsidian ]]; then
  cd /workspaces/obsidian
fi
