# Add ~/bin to PATH
export PATH="$HOME/bin:$PATH"

# Run the .env.sh file if it exists to set up system specific environment variables
[ -f ~/.env.sh ] && source ~/.env.sh

export PATH="$HOME/.local/bin:$PATH"