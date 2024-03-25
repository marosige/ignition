#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/bootstrap.sh

###############################################################################
# Setting preferences
###############################################################################

# If any command fails, exit with 1 at the end
exit=0

# This sets something
command || exit=1

# This sets something
command || exit=1

exit $exit
