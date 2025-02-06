# Add ~/bin to PATH
export PATH="$HOME/bin:$PATH"

# Enable command auto-correction
shopt -s cdspell

# Enable case-insensitive completion
bind "set completion-ignore-case on"

# Autocompletion
if [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
fi

# Prompt settings
PS1='[\u@\h \W]\$ '

# Enable history
HISTSIZE=1000
HISTFILE=~/.bash_history
HISTCONTROL=ignoredups:erasedups
shopt -s histappend

# Alias for common commands
alias ll='ls -lah'
alias gs='git status'
alias ..='cd ..'

# Set the default editor (optional)
export EDITOR=nano