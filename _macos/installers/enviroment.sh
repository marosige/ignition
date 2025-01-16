#!/usr/bin/env bash

###############################################################################
# Enviroment
###############################################################################

task "Source enviromental variables"

# Function to add source command to shell configuration file
add_source_to_shell_config() {
  local shell_config="$1"
  local source_command="source $IG_OS/files/env/env.sh"

  if ! grep -qF "$source_command" "$shell_config" 2>/dev/null; then
      printf "\n# Source enviromental variables\n" >> "$shell_config"
      echo "$source_command" >> "$shell_config"
      success "$source_command added to $shell_config"
  else
      success "$source_command already present in $shell_config"
  fi
}

# Add source command to all shell configuration files
add_source_to_shell_config "$HOME/.bashrc"
add_source_to_shell_config "$HOME/.zshrc"
add_source_to_shell_config "$HOME/.config/fish/config.fish"
