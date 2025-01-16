#!/bin/bash

IG_INSTALLER_ORDER=(
  directory-structure # create directories
  dotfiles            # link the dotfiles
  environment         # add environmental variables
  homebrew            # install software
)

# Export the array to make it available to other scripts
export IG_INSTALLER_ORDER
