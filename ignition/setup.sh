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

# Function to run a specific task for all systems
runTaskForAllSystems() {
  local task=$1
  local description=$2

  for base_dir in "$IGNITION_SYSTEM" "$IGNITION_SYSTEM_PRIVATE"; do
    # Skip if the base_dir doesn't exist
    [ ! -d "$base_dir" ] && continue

    for system_path in "$base_dir"/*; do
      # Skip if it's not a folder or is a hidden folder
      [[ ! -d "$system_path" || "$(basename "$system_path")" == .* ]] && continue

      export IGNITION_ACTIVE_SYSTEM=$system_path
      system_name=$(basename "$system_path")
      echo -e "$IGNITION_TASK $description for $system_name"

      case $task in
        create_directories)
          SCRIPT="$IGNITION_ACTIVE_SYSTEM/create_directories.sh"
          [ -f "$SCRIPT" ] && bash "$SCRIPT"
          ;;
        link_files)
          FOLDER="$IGNITION_ACTIVE_SYSTEM/dotfiles"
          [ -d "$FOLDER" ] && lib_link_directories "$FOLDER" "$HOME"
          ;;
        install_packages)
          SCRIPT="$IGNITION_ACTIVE_SYSTEM/install_packages.sh"
          [ -f "$SCRIPT" ] && bash "$SCRIPT"
          ;;
        configure_preferences)
          FOLDER="$IGNITION_ACTIVE_SYSTEM/preferences"
          [ -d "$FOLDER" ] && lib_run_scripts_in_folder "$FOLDER" "$HOME"
          ;;
      esac
    done
  done
}

# Run tasks in order
if $RUN_CREATE_DIRECTORIES; then
  runTaskForAllSystems "create_directories" "Creating directories"
fi

if $RUN_LINK_FILES; then
  runTaskForAllSystems "link_files" "Linking files"
fi

if $RUN_INSTALL_PACKAGES; then
  runTaskForAllSystems "install_packages" "Installing packages"
fi

if $RUN_CONFIGURE_PREFERENCES; then
  runTaskForAllSystems "configure_preferences" "Configuring preferences"
fi