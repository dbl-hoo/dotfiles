# ~/.bashrc — managed via git
# kirkham dotfiles

# Exit if not interactive
[[ $- != *i* ]] && return

# Enable color support
export CLICOLOR=1
export LS_COLORS=di=34:ln=35:so=32:pi=33:ex=31

# Prompt with hostname awareness
HOST_COLOR="32"   # green default
case "$(hostname)" in
  hyperion) HOST_COLOR="31" ;;   # red
  coruscant) HOST_COLOR="33" ;;  # yellow
  mustafar) HOST_COLOR="31" ;;
esac

PS1="\[\e[1;${HOST_COLOR}m\]\u@\h\[\e[0m\] \[\e[1;34m\]\w\[\e[0m\] \$ "

# Aliases
alias ll='ls -lah --color=auto'
alias gs='git status'

# fastfetch (only on SSH)
if command -v fastfetch >/dev/null 2>&1 && [[ -n "$SSH_CONNECTION" ]]; then
  fastfetch
fi