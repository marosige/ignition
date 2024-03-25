#!/usr/bin/env bash

# Source .env.sh if IGNITION_ROOT is not set
# This means ignition is downloaded, but not installed
if [ -z "${IGNITION_ROOT+x}" ]; then
  source $HOME/.ignition/global/dotfiles/env/env.sh
fi

source $IGNITION_LIB_PRINT
source $IGNITION_LIB_TOOLS

cd $IGNITION_ROOT
