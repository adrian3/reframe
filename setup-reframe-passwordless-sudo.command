#!/bin/bash
set -e

echo "This will ask for the Pi password once, then enable passwordless sudo for cam."
echo

ssh -t \
  -i "$HOME/.ssh/einkpi_ed25519" \
  -o UserKnownHostsFile=/tmp/reframe_diag_known_hosts \
  -o StrictHostKeyChecking=accept-new \
  cam@192.168.86.217 \
  'echo "cam ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/cam-nopasswd >/dev/null &&
   sudo chmod 440 /etc/sudoers.d/cam-nopasswd &&
   sudo visudo -cf /etc/sudoers.d/cam-nopasswd &&
   echo "Passwordless sudo enabled for cam"'

echo
echo "Done. You can close this Terminal window."
read -r -p "Press Return to close... " _
