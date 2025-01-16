task="Uninstall all formulae not listed in the Brewfile"
    task $task
    brew update > /dev/null 2>&1
    cleanup_output=$(brew bundle cleanup --file=$BREWFILE | sed '$d')
    if [ -z "$cleanup_output" ]; then
      success $task
      message "Nothing to uninstall"
    else
      clear_line  # Remove the task message
      echo "$cleanup_output" | while IFS= read -r line; do
        [[ $line == *":" ]] && warn "$line" || list "$line"
      done
      if confirm "Do you want to proceed with the cleanup?"; then
        task $task
        brew bundle cleanup --force --file=$BREWFILE > /dev/null 2>&1 &&
          success $task ||
          fail $task
      else
        success "Cleanup aborted. No changes have been made."
      fi
    fi
