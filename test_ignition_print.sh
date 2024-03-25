#!/usr/bin/env bash

###############################################################################
# Demo script demonstrating the possibilities with the ignition print library
# Made by Gergely Marosi - https://github.com/marosige
###############################################################################

source $HOME/.ignition/libs/print.sh

title "Title"
message "Message"
bold "Bold"
list "List"
number "5" "Number"
info "Info"
warn "Warn"
question "Question"
task "Task"
success "Success"
fail "Fail"
confirm "Confirm?"

# Do not call
menu_example() {
  options=("Menu item 1" "Menu item 2" "Menu item 3")
  choice=$(gum choose "${options[@]}")
  case "$choice" in
    "${options[0]}" )
      echo "You choose ${options[0]}"
    ;;
    "${options[1]}" )
      echo "You choose ${options[1]}"
    ;;
    "${options[2]}" )
      echo "You choose ${options[2]}"
    ;;
    "${options[3]}" )
      echo "You choose ${options[3]}"
    ;;
    "${options[4]}" )
      echo "You choose ${options[4]}"
    ;;
    "${options[5]}" )
      echo "You choose ${options[5]}"
    ;;
    "${options[6]}" )
      echo "You choose ${options[6]}"
    ;;
    "${options[7]}" )
      echo "You choose ${options[7]}"
    ;;
    "${options[8]}" )
      echo "You choose ${options[8]}"
    ;;
    "${options[9]}" )
      echo "You choose ${options[9]}"
    ;;
    "${options[10]}" )
      echo "You choose ${options[10]}"
    ;;
  esac
}
