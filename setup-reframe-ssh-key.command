#!/bin/bash
set -e

KEY="$HOME/.ssh/einkpi_ed25519.pub"
PI="cam@192.168.86.217"

if [ ! -f "$KEY" ]; then
  echo "Missing public key: $KEY" >&2
  exit 1
fi

cat "$KEY" | ssh \
  -o UserKnownHostsFile=/tmp/reframe_diag_known_hosts \
  -o StrictHostKeyChecking=accept-new \
  "$PI" \
  'pub="$(cat)"; mkdir -p ~/.ssh; chmod 700 ~/.ssh; touch ~/.ssh/authorized_keys; grep -qxF "$pub" ~/.ssh/authorized_keys || printf "%s\n" "$pub" >> ~/.ssh/authorized_keys; chmod 600 ~/.ssh/authorized_keys'

echo "SSH key installed for $PI"
