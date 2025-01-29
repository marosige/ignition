# To use the onedark Kitty theme, disable the onedark fish theme.
# It overwrites the onedark Kitty theme.
set onedark true

if status is-interactive
  if $onedark
      # Set OneDark Color Scheme
      set -l onedark_options '-b'

      if set -q VIM
          # Using from vim/neovim.
          set onedark_options "-256"
      else if string match -iq "eterm*" $TERM
          # Using from emacs.
          function fish_title; true; end
          set onedark_options "-256"
      end

      set_onedark $onedark_options
  end
end

# Source enviromental variables
source ~/.env.sh

# Aliases
alias lsa="ls -all"                           # List all files from folder
alias mkd="mkdir $argv; and cd $argv"         # Create a new directory and enter it
alias gituser="git config --list | grep user" # Print git user info of current/working directory.
alias weather="curl wttr.in/~Budapest"        # Check the weather
thefuck --alias | source                      # Configure fuck alias

# Add my bin folders to the PATH
set PATH $IGNITION_GLB_BIN $PATH
set PATH $IGNITION_MAC_BIN $PATH

# Add Android sdk platrofn-tools (adb, etc...) to the PATH
set PATH ~/Library/Android/sdk//platform-tools/ $ PATH
