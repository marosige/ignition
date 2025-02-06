# Add ~/bin to PATH
export PATH="$HOME/bin:$PATH"

# Enable command auto-correction
setopt correct

# Enable case-insensitive completion
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

# Autocompletion
autoload -U compinit
compinit

# Prompt settings
PROMPT='%F{cyan}%n@%m%f:%F{yellow}%~%f$ '

# Enable history
HISTSIZE=1000
SAVEHIST=1000
HISTFILE=~/.zsh_history

# Syntax highlighting (optional)
# If you want syntax highlighting, remove the comment and ensure `zsh-syntax-highlighting` is installed
# source /path/to/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Alias for common commands
alias ll='ls -lah'
alias gs='git status'
alias ..='cd ..'

# Set the default editor (optional)
export EDITOR=nano

# Load the `zsh-autosuggestions` plugin if installed, otherwise leave it out for lightweight config
# source $HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh