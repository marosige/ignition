#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/bootstrap.sh

###############################################################################
# This script sets up ignition for all systems
###############################################################################

# Default values for jobs
RUN_UPDATE_SYSTEM=false
RUN_CREATE_DIRECTORIES=false
RUN_LINK_FILES=false
RUN_INSTALL_PACKAGES=false
RUN_CONFIGURE_PREFERENCES=false

# Parse command-line options
while [[ $# -gt 0 ]]; do
  case $1 in
    --update-system)
      RUN_UPDATE_SYSTEM=true
      shift
      ;;
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

job() {
  TITLE=$1
  SCRIPT=$2
  JOB="$IGNITION_ACTIVE_SYSTEM/job/${SCRIPT}.sh"
  if [ -f "$JOB" ]; then
    echo -e "$IGNITION_TASK $TITLE"
    bash "$JOB"
  fi
}  

runJobs() {
  system_path=$1
  if [[ -d "$system_path" ]]; then
    export IGNITION_ACTIVE_SYSTEM="$system_path"
    system_name=$(basename "$system_path")
    echo -e "$IGNITION_TASK Setting up $system_name"
    $RUN_UPDATE_SYSTEM && job "Updating system..." update_system
    $RUN_CREATE_DIRECTORIES && job "Creating directories..." create_directories
    $RUN_LINK_FILES && job "Linking files..." link_files
    $RUN_INSTALL_PACKAGES && job "Installing packages..." install_packages
    $RUN_CONFIGURE_PREFERENCES && job "Configuring preferences..." configure_preferences
    echo -e "$IGNITION_DONE $system_name setup completed"
  fi
}

# Loop through each system directory
for system_path in "$IGNITION_SYSTEM"/*; do
  runJobs "$system_path"
done

# Loop through each private system directory (stored in a separate repository)
for system_path in "$IGNITION_SYSTEM_PRIVATE"/*; do
  # Skip hidden folders (especially .git)
  if [[ -d "$system_path" && "$(basename "$system_path")" != .* ]]; then
    runJobs "$system_path"
  fi
done