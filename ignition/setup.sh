#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/ignition/bootstrap.sh

###############################################################################
# This script sets up ignition for all systems
###############################################################################

# Default values for jobs
RUN_CREATE_DIRECTORIES=false
RUN_LINK_FILES=false
RUN_INSTALL_PACKAGES=false
RUN_CONFIGURE_PREFERENCES=false

# Parse command-line options
while [[ $# -gt 0 ]]; do
  case $1 in
    --create-directories)
      RUN_CREATE_DIRECTORIES=true
      shift
      ;;
    --link-files)
      RUN_LINK_FILES=true
      shift
      ;;
    --install-packages)
      RUN_INSTALL_PACKAGES=true
      shift
      ;;
    --configure-preferences)
      RUN_CONFIGURE_PREFERENCES=true
      shift
      ;;
    --all)
      RUN_UPDATE_SYSTEM=true
      RUN_CREATE_DIRECTORIES=true
      RUN_LINK_FILES=true
      RUN_INSTALL_PACKAGES=true
      RUN_CONFIGURE_PREFERENCES=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

setupSystem() {
  # Skip if it's not a folder or is a hidden folder
  [[ ! -d "$1" || "$(basename "$1")" == .* ]] && return

  export IGNITION_ACTIVE_SYSTEM=$1
  system_name=$(basename "$system_path")
  echo -e "$IGNITION_TASK Setting up $system_name"

  if $RUN_CREATE_DIRECTORIES; then
    echo -e "$IGNITION_TASK Creating directories..."
    SCRIPT="$IGNITION_ACTIVE_SYSTEM/create_directories.sh"
    [ -f "$SCRIPT" ] && bash "$SCRIPT"
  fi

  if $RUN_LINK_FILES; then
    echo -e "$IGNITION_TASK Linking files..."
    FOLDER="$IGNITION_ACTIVE_SYSTEM/dotfiles"
    [ -d "$FOLDER" ] && lib_link_directories "$FOLDER" "$HOME"
  fi

  if $RUN_INSTALL_PACKAGES; then
    echo -e "$IGNITION_TASK Installing packages..."
    SCRIPT="$IGNITION_ACTIVE_SYSTEM/install_packages.sh"
    [ -f "$SCRIPT" ] && bash "$SCRIPT"
  fi

  if $RUN_CONFIGURE_PREFERENCES; then
    echo -e "$IGNITION_TASK Configuring preferences..."
    FOLDER="$IGNITION_ACTIVE_SYSTEM/preferences"
    [ -d "$FOLDER" ] && lib_run_scripts_in_folder "$FOLDER" "$HOME"
  fi

  echo -e "$IGNITION_DONE $system_name setup completed"
}

# Loop through each system directory
for system_path in "$IGNITION_SYSTEM"/*; do
  setupSystem "$system_path"
done

# Loop through each private system directory (stored in a separate repository)
for system_path in "$IGNITION_SYSTEM_PRIVATE"/*; do
  setupSystem "$system_path"
done