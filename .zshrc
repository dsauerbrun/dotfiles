export PATH="$HOME/.opencode/bin:$PATH"

export ZSH="${HOME}/.oh-my-zsh"

# theme
ZSH_THEME="apple"

# aliases
source $ZSH/oh-my-zsh.sh
source $HOME/.aliases

TERM=xterm-256color

# rex: show the Tailscale sign-in link on SSH login when the server needs one.
# --autostart=false keeps a status check from launching a server without --tailscale.
if [[ -n "$SSH_CONNECTION" ]] && (( $+commands[rex] )); then
  rex_login_url=$(rex server status --autostart=false --timeout 2s 2>/dev/null | sed -n 's/^  authenticate: //p')
  [[ -n "$rex_login_url" ]] && echo "rex: Tailscale sign-in needed: $rex_login_url"
  unset rex_login_url
fi
