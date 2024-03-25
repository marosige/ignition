#!/usr/bin/env bash

###############################################################################
# Make your scripts print in a nice colorful way
# Made by Gergely Marosi - https://github.com/marosige
#
# How to
#   Log tasks:
#     message="Task description"
#     task_inline $message
#     command && success $message || fail $message;
#
###############################################################################

# Define ANSI escape codes
DEFAULT='\e[0m'
DEFAULT_BOLD='\e[0;1m'

BLACK="\e[0;30m"
BRIGHT_BLACK="\e[0;90m"
BRIGHT_BLACK_BOLD="\e[0;1;90m"

RED="\e[0;31m"
BRIGHT_RED="\e[0;91m"
BRIGHT_RED_BOLD="\e[0;1;91m"

GREEN="\e[0;32m"
BRIGHT_GREEN="\e[0;92m"
BRIGHT_GREEN_BOLD="\e[0;1;92m"

YELLOW="\e[0;33m"
BRIGHT_YELLOW="\e[0;93m"
BRIGHT_YELLOW_BOLD="\e[0;1;93m"

BLUE="\e[0;34m"
BRIGHT_BLUE="\e[0;94m"
BRIGHT_BLUE_BOLD="\e[0;1;94m"

MAGENTA="\e[0;35m"
BRIGHT_MAGENTA="\e[0;95m"
BRIGHT_MAGENTA_BOLD='\e[0;1;95m'

CYAN="\e[0;36m"
BRIGHT_CYAN="\e[0;96m"
BRIGHT_CYAN_BOLD='\e[0;1;96m'

WHITE="\e[0;37m"
BRIGHT_WHITE="\e[0;97m"

YELLOW_BOLD='\e[0;1;33m'
BRIGHT_BLUE='\e[0;94m'
BRIGHT_BLUE_BOLD='\e[0;1;94m'
BRIGHT_GREEN='\e[0;92m'
BRIGHT_RED='\e[0;91m'

CLEAR_LINE='\e[2K'

HEAVY_CHECK_MARK='\xE2\x9C\x94'

title () {
  title_inline $*
  printf "\n"
}

title_inline () {
  printf "${CLEAR_LINE}${BRIGHT_CYAN_BOLD}#${DEFAULT_BOLD} %s${DEFAULT}" "$*"
}

message () {
  message_inline $*
  printf "\n"
}

message_inline () {
  printf "${CLEAR_LINE}${DEFAULT}  %s" "$*"
}

bold () {
  bold_inline $*
  printf "\n"
}

bold_inline () {
  printf "${CLEAR_LINE}${DEFAULT_BOLD}  %s${DEFAULT}" "$*"
}

list () {
  list_inline $*
  printf "\n"
}

list_inline () {
  printf "${CLEAR_LINE}${DEFAULT}> %s" "$*"
}

number () {
  number_inline $*
  printf "\n"
}

number_inline () {
  printf "${CLEAR_LINE}${DEFAULT}%s %s" "$1" "${@:2}" # Exclude the first argument for the string
}

info () {
  info_inline $*
  printf "\n"
}

info_inline () {
  printf "${CLEAR_LINE}${BRIGHT_BLUE_BOLD}!${DEFAULT} %s" "$*"
}

warn () {
  warn_inline $*
  printf "\n"
}

warn_inline () {
  printf "${CLEAR_LINE}${BRIGHT_MAGENTA_BOLD}!${DEFAULT_BOLD} %s${DEFAULT}" "$*"
}

question () {
  question_inline $*
  printf "\n"
}

question_inline () {
  printf "${CLEAR_LINE}${YELLOW}?${DEFAULT} %s" "$*"
}

# Task doesn't have a \n at the end.
# It should be overwritten with the next line, like a success/fail message
task () {
  task_inline $*
  printf "\n"
}

task_inline () {
  printf "${CLEAR_LINE}${CYAN}…${DEFAULT} %s" "$*"
}

success () {
  success_inline $*
  printf "\n"
}

success_inline () {
  printf "${CLEAR_LINE}${BRIGHT_GREEN}${HEAVY_CHECK_MARK}${DEFAULT} %s" "$*"
}

fail () {
  fail_inline $*
  printf "\n"
}

fail_inline () {
  printf "${CLEAR_LINE}${BRIGHT_RED}x${DEFAULT} %s" "$*"
}

confirm () {
  printf "${CLEAR_LINE}${YELLOW}?${DEFAULT} %s" "$*"
  read -r -p $'\e[0;1m [Y/n] \e[0m' response
  case "$response" in
      [yY][eE][sS]|[yY])
          true
          ;;
      *)
          false
          ;;
  esac
}
