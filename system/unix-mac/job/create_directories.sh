#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/bootstrap.sh

###############################################################################
# Directory Structure
###############################################################################

mkdir_withlog ~/workspace               # For my git repos
mkdir_withlog ~/workspace/work          # For my work projects
mkdir_withlog ~/workspace/personal      # For my personal projects
mkdir_withlog ~/workspace/playground    # For temporarly projects
mkdir_withlog ~/workspace/third         # For 3rd party projects, libs sources
