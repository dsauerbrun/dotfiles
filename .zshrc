export ZSH="${HOME}/.oh-my-zsh"

# theme
ZSH_THEME="linuxonly"

# aliases
source $ZSH/oh-my-zsh.sh
#source $HOME/.aliases

# git
alias gs="git status"
alias ga="git add"
alias gaa="git add ."
alias gap="git add -p"

alias gcm="git commit -m"

alias gco="git checkout"
alias gcob="git checkout -b"

alias gp="git pull"
alias gpush="git push"
alias gpfwl="git push --force-with-lease"

alias unstage="git restore --staged"
alias reset-last="git reset --soft HEAD^"

alias stash-unstaged="git stash push --keep-index -u"

# work-specific
alias dev="make dev-start-web"
alias integration="make dev-start-integration"
alias types="turbo generate-types"
alias typecheck="turbo typecheck"
alias typecheck-web="turbo typecheck -F web-client"
alias make-types="make generate-types"
alias story="make dev-storybook"
alias test="make unit-test"
