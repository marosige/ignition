#!/usr/bin/env bash

###############################################################################
# Delete all sample files, nfo files, sample folders and empty folders in a directory
# This is useful for cleaning up video directories after downloading
# It is recommended to first list the files and folders to be deleted before running the delete commands
###############################################################################

# Check for -y flag
AUTO_CONFIRM=false
if [[ "$1" == "-y" ]]; then
    AUTO_CONFIRM=true
fi

# Function to log and delete files
log_and_delete() {
    local description="$1"
    local find_command="$2"
    local delete_command="$3"

    echo "### $description ###"

    if [ "$AUTO_CONFIRM" = true ]; then
        eval "$delete_command"
    else
        eval "$find_command"
        read -p "Do you want to delete these files? (y/N): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            eval "$delete_command"
        else
            echo "Skipping deletion of $description."
        fi
    fi
}

# Delete sample and nfo files
log_and_delete "SAMPLE AND NFO FILES" \
    "find . \( -name '*sample*' -o -name '*.nfo' \) -type f -print" \
    "find . \( -name '*sample*' -o -name '*.nfo' \) -type f -delete"

# Delete sample folders
log_and_delete "SAMPLE FOLDERS" \
    "find . -name 'Sample' -type d -print" \
    "find . -name 'Sample' -type d -delete"

# Delete empty folders
log_and_delete "EMPTY FOLDERS" \
    "find . -empty -type d -print" \
    "find . -empty -type d -delete"