

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
