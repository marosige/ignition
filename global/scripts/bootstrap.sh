#!/usr/bin/env bash

###############################################################################
# This script sets the enviroment for running Ignition
#
# This script will:
# * set the enviroment variables
# * source all libraries
# * install dependencies
#
# Made by Gergely Marosi - https://github.com/marosige
###############################################################################

library_mode=false
custom_root_dir=""

# Function to print usage information
bootstrap_print_usage() {
    echo "Usage: $0 [-l] [-d directory]"
    echo "  -l : Library mode (source functions but do not execute)"
    echo "  -d directory : Set custom root directory"
    echo "  -h : Print usage information"
}

# Parse command line options
while getopts "ld:h" opt; do
    case $opt in
        l) library_mode=true ;;
        d) custom_root_dir="$OPTARG" ;;
        h) bootstrap_print_usage
           exit 0 ;;
        \?) echo "Invalid option: -$OPTARG" >&2
            bootstrap_print_usage
            exit 1 ;;
    esac
done
shift $((OPTIND - 1))

echo "Shell: $SHELL"
echo "0: $0"
# Select ignition root folder path
if [ -n "$custom_root_dir" ]; then              # Check if custom directory is enabled
  echo "custom dir"
  ignition="$custom_root_dir"                   # Set provided directory
elif [[ "$0" == -* || "$0" == "bash" ]]; then     # Check if the script is being executed from the internet or by Bash (Bash when frunning from get_ignition.sh)
  echo "default dir - curl"
  ignition="$HOME/.ignition"                    # Set default directory
else                                            # Otherwise
  echo "current dir - hard drive"
  ignition="$(dirname "$(readlink -f "$0")")"   # Set the directory of the script
fi
echo "ignition: $ignition"

# Set ignition environment variables based on the provided home directory
bootstrap_set_environment_variables() {
  export IGNITION_HOME="$1"

  export IGNITION_SETUP_ROOT=""   # Clear it, because it's no longer a setup

  local timestamp="$(date +'%Y_%m_%d-%H_%M_%S')"
  export IGNITION_LOG_DIR="$IGNITION_HOME/logs"
  export IGNITION_LOG_FILE="$IGNITION_LOG_DIR/$timestamp.log"

  declare -A platforms=(
      [GLB]="global"
      [MAC]="macOS"
      [LAB]="Ubuntu"
  )
  declare -A directories=(
      [BIN]="bin"
      [DOT]="dotfiles"
      [LIB]="libs"
      [SCR]="scripts"
  )
  for platform in "${!platforms[@]}"; do
    # Set the platform directory
    export IGNITION_"$platform"="$IGNITION_HOME/${platforms[$platform]}"

    for directory in "${!directories[@]}"; do
      # Set the platform subdirectories
      export IGNITION_"$platform"_"$directory"="$IGNITION_HOME/${platforms[$platform]}/${directories[$directory]}"
    done
  done
}

# Source all .sh files in the specified directory
declare -a sourced_libraries
bootstrap_source_library() {
  local directory="$1"
  if [ -d "$directory" ]; then
    for lib in "$directory"/*.sh; do
      # Ensure that only regular files are sourced
      if [ -f "$lib" ]; then
        source "$lib"
        sourced_libraries+=("$lib")
      fi
    done
  fi
}

bootstrap_source_all_libraries() {
  bootstrap_source_library $IGNITION_GLB_LIB
  bootstrap_source_library $IGNITION_MAC_LIB
  bootstrap_source_library $IGNITION_LAB_LIB
}

# Install dependencies if missing
# Run after sourceing IGNITION_GLB_LIB so you have print and helper functions
# > bootstrap_source_library $IGNITION_GLB_LIB
bootstrap_check_dependencies() {
  return=0
  if running_on_macos ; then
    if ! is_command_exists brew ; then /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)" || return=1 ; fi
    if ! is_command_exists git ; then brew install git || return=1 ; fi
    if ! is_command_exists gum ; then brew install gum || return=1 ; fi
  elif running_on_ubuntu ; then
    # Install git
    if ! is_command_exists git ; then sudo apt install git || return=1 ; fi
    # Install gum
    if ! is_command_exists gum ; then
      sudo mkdir -p /etc/apt/keyrings
      curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
      echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
      sudo apt install gum || return=1
    fi
  fi
  return $return
}

# Log the enviroment setup
bootstrap_log() {
  if [ -n "$IGNITION_LOG_DIR" ] && [ -d "$IGNITION_LOG_DIR" ]; then
    echo "Ignition home is $IGNITION_HOME" >> $IGNITION_LOG_FILE

    echo >> $IGNITION_LOG_FILE
    echo "env:" >> $IGNITION_LOG_FILE
    env | sort | grep IGNITION >> $IGNITION_LOG_FILE

    echo >> $IGNITION_LOG_FILE
    echo "libs:" >> $IGNITION_LOG_FILE
    for lib in "${sourced_libraries[@]}"; do
      echo "$lib" >> $IGNITION_LOG_FILE
    done

    echo >> $IGNITION_LOG_FILE
  fi
}

if $library_mode; then
  export IGNITION_SETUP_ROOT="$ignition"    # gets cleared after calling set_environment_variables()
else
  bootstrap_set_environment_variables $ignition
  bootstrap_source_all_libraries
  bootstrap_check_dependencies
  bootstrap_log
fi
