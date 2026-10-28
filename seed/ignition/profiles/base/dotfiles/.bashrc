export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export HISTFILE=~/.bash_history
export HISTSIZE=1000
export SAVEHIST=1000

# Add ~/bin to PATH
export PATH="$HOME/bin:$PATH"

# Run the .env.sh file if it exists to set up system specific environment variables
[ -f ~/.env.sh ] && source ~/.env.sh