#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/bootstrap.sh

###############################################################################
# Configuring laptop to run with lid closed
###############################################################################
exit=0

echo -e "$IGNITION_WARN Skipping lid closed setup now..."
exit 0

if grep -q open /proc/acpi/button/lid/*/state; then
  sudo sed -i 's/#HandleLidSwitch=suspend/HandleLidSwitch=ignore/' /etc/systemd/logind.conf || exit=1
  sudo systemctl restart systemd-logind || exit=1
fi

exit $exit
