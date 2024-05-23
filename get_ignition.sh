#!/usr/bin/env bash

###############################################################################
# This script downloads ignition and dependencies
# Made by Gergely Marosi - https://github.com/marosige
###############################################################################

source <(curl -s https://raw.githubusercontent.com/marosige/ignition/main/global/libs/print.sh)
source <(curl -s https://raw.githubusercontent.com/marosige/ignition/main/global/libs/helper.sh)

# Run bootstrap.sh in library mode to set up the enviroment for ignition.
# If get_ignition.sh has an argument pass it to bootstrap.sh as the base directory
bootstrap_url="https://raw.githubusercontent.com/marosige/ignition/main/global/scripts/bootstrap.sh"
if [ $# -gt 0 ]; then
  source <(curl -s "$bootstrap_url") -l -d $1
else
  source <(curl -s "$bootstrap_url") -l
fi

if running_on_macos; then
  os="macOS"
  function="daily driver"
elif running_on_ubuntu; then
  os="Ubuntu"
  function="homelab"
else
  fail "Unsupported operating system"
  info "Ignition is available on macOS and Ubuntu"
  exit 1
fi

# If IGNITION_SETUP_ROOT is not set, can't continue with setup
if [ -z "$IGNITION_SETUP_ROOT" ]; then
  fail "Download destination for ignition is unspecified"
  exit 1
fi

# If ignition folder exists exit download script
if [ -d "$IGNITION_SETUP_ROOT" ]; then
  fail "Ignition folder already exist at $IGNITION_SETUP_ROOT"
  exit 1
fi

title "Welcome to Ignition Downloader!"
message "Ignition is designed to set up your $os environment as a $function."
message "This downloader performs the following actions:"
message "1. Installing missing igtnition dependencies"
if running_on_macos && ! is_command_exists brew ; then
  message "   • Homebrew (the Missing Package Manager for macOS)"
fi
if ! is_command_exists git ; then
  message "   • git (distributed version control system)"
fi
if ! is_command_exists gum ; then
  message "   • gum (a tool for glamorous shell scripts)"
fi
message "2. Downloading Ignition into $IGNITION_SETUP_ROOT"
message "3. Running ignition for the first time."
if ! confirm "Do you want to continue?" ; then
  fail "Setup aborted. No changes have been made."
  exit 1
fi

message="Installing missing dependencies"
task $message
bootstrap_check_dependencies
[ $? -eq 0 ] && success "$message" || fail "$message"

message="Sparse cloning the $os $function part of the repository into $IGNITION_SETUP_ROOT"
task $message
git_success=0
git clone --no-checkout https://github.com/marosige/ignition "$IGNITION_SETUP_ROOT" || git_success=1
git -C "$IGNITION_SETUP_ROOT" sparse-checkout init --cone || git_success=1
git -C "$IGNITION_SETUP_ROOT" sparse-checkout set global/ "$os/" || git_success=1
git -C "$IGNITION_SETUP_ROOT" checkout main || git_success=1
[ $git_success -eq 0 ] && success "$message" || fail "$message"

cd $IGNITION_SETUP_ROOT
if [ -f "ignition.sh" ]; then
  success "Starting Ignition."
  #bash ignition.sh
  pwd
else
  fail "Can't start ignition"
fi
