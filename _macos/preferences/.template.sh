#!/usr/bin/env bash

###############################################################################
# Template
###############################################################################
exit=0

# This sets something
command || exit=1

# This sets something
command || exit=1

exit $exit
