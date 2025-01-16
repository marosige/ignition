#!/usr/bin/env bash

###############################################################################
# Update
###############################################################################

message="Checking for macOS updates"
task $message
# List all available updates to a variable
update_output=$(sudo softwareupdate --list)
# Check the exit status of the previous command
if [ $? -eq 0 ]; then
    # The command was successful
    echo -e "$message\n$update_output" >> $log_file

    # Check if there are any lines containing "No new software available."
    if echo "$update_output" | grep -q "No new software available."; then
        success "$message: System is up-to-date!"
    else
        success "$message: Software Update found!"

        message="Downloading the update"
        t "$message"
        q ""
        if output=$(sudo softwareupdate -ia --verbose 2>&1); then
          # Filter the output to show only "Downloaded" or "Failed" lines
          filtered_output=$(echo "$output" | grep -E "Downloaded|Failed")
          success $filtered_output
          info "Don't forget to reboot your system to install the update!"
        else
          # Filter the output to show only "Downloaded" or "Failed" lines
          filt./ered_output=$(echo "$output" | grep -E "Downloaded|Failed")
          fail $filtered_output
        fi
        echo -e "$message\n$output" >> $log_file
    fi
else
    # The command failed
    fail $message
    echo -e "!!!! ERROR  !!!!\n$message\n$update_output" >> $log_file
    exit 1
fi
