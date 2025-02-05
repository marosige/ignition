#!/usr/bin/env bash

###############################################################################
# This script links files (usually dotfiles)
#
# Parameters:
#   1) source folder: The root directory where files to link are stored.
#   2) destination folder: The directory where symbolic links will be created.
#
# Usage:
#   ./link_directory.sh <source-folder> <destination-folder>
#
# Made by Gergely Marosi - https://github.com/marosige
###############################################################################

# Check if the correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo -e "${IGNITION_FAIL} Usage: $0 <source-folder> <destination-folder>"
    exit 1
fi

SOURCE_DIR="$1"
DEST_DIR="$2"

echo -e "$IGNITION_TASK Linking files from $SOURCE_DIR to $DEST_DIR"

# Check if the source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo -e "${IGNITION_FAIL} Error: Source directory does not exist!"
    exit 1
fi

# Check if the destination directory exists
if [ ! -d "$DEST_DIR" ]; then
    echo -e "${IGNITION_FAIL} Error: Destination directory does not exist!"
    exit 1
fi

# Iterate through all files in the source directory, including subdirectories
find "$SOURCE_DIR" -type f | while read -r source_file; do
    # Determine the relative path of the source file
    relative_path="${source_file#"$SOURCE_DIR"/}"

    # Determine the destination file path
    dest_file="$DEST_DIR/$relative_path"

    # Create the destination folder structure if it doesn't exist
    dest_folder=$(dirname "$dest_file")
    mkdir -p "$dest_folder"

    # Check if a file already exists at the destination
    if [ -e "$dest_file" ]; then
        # Check if it's a symlink
        if [ -L "$dest_file" ]; then
            # It's a symlink, so remove it and create a new symlink
            rm "$dest_file"
            ln -s "$source_file" "$dest_file"
            echo -e "${IGNITION_DONE} Overwritten symlink: $dest_file -> $source_file"
        elif [ -f "$dest_file" ]; then
            # It's a regular file, so do not override and print a message
            echo -e "${IGNITION_FAIL} Skipping: Regular file exists at destination: $dest_file"
        fi
    else
        # If the destination file doesn't exist, create a symlink
        ln -s "$source_file" "$dest_file"
        echo -e "${IGNITION_DONE} Created symlink: $dest_file -> $source_file"
    fi
done

echo -e "${IGNITION_DONE} Symlink creation complete!"
