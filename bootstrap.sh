#!/usr/bin/env bash

###############################################################################
# This script sets the enviroment to run Ignition
#   • IG_ROOT - Root directory of Ignition
#   • IG_OS - OS specific (macos or ubuntu) directory
#   • Sourcing all the libs from the libs directory
#   • Sourcing the env.sh file
#
# Made by Gergely Marosi - https://github.com/marosige
###############################################################################

# Set ignition path variable and CD into it
export IG_ROOT=$HOME/.ignition
if [ ! -d "$IG_ROOT" ]; then
  echo "Error: The directory $IG_ROOT does not exist. Download ignition first!" >&2
  exit 1
fi
cd $IG_ROOT

# Set ignition OS variable
MACOS_DIR="$IGNITION/_macos"
UBUNTU_DIR="$IGNITION/_ubuntu"
if [ -d "$MACOS_DIR" ]; then
  export IG_OS=$MACOS_DIR
elif [ -d "$UBUNTU_DIR" ]; then
  export IG_OS=$UBUNTU_DIR
else
  echo "Error: Can't identify OS." >&2
  exit 1
fi

export IG_GLOBAL="$IGNITION/global"

# Source all the libs
LIBS_DIR="$IG_GLOBAL/libs"
for lib in "$LIBS_DIR"/*.sh; do
  if [ -f "$file" ]; then
    source "$file"
  fi
done

# Source env
source "$IG_OS/env/env.sh"
# TODO source "$IG_GLOBAL/env/env.sh"
