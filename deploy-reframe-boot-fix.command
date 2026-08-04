#!/bin/bash
set -e

PI=cam@192.168.86.217
SSH_OPTS=(-i "$HOME/.ssh/einkpi_ed25519" -o UserKnownHostsFile=/tmp/reframe_diag_known_hosts -o StrictHostKeyChecking=accept-new)

scp "${SSH_OPTS[@]}" \
  /Users/adehanft/Desktop/reframe/reframe.service \
  /Users/adehanft/Desktop/reframe/reframe-dashboard.service \
  /Users/adehanft/Desktop/reframe/install.sh \
  /Users/adehanft/Desktop/reframe/reframe-wait-camera \
  "$PI:/home/cam/reframe/"

ssh -t "${SSH_OPTS[@]}" "$PI" '
set -e
cd /home/cam/reframe
chmod +x install.sh reframe-wait-camera
sudo cp reframe.service /etc/systemd/system/reframe.service
sudo cp reframe-dashboard.service /etc/systemd/system/reframe-dashboard.service
sudo systemctl daemon-reload
sudo systemctl reset-failed reframe.service reframe-dashboard.service reframe-dashboard-proxy.service || true
sudo systemctl stop reframe-dashboard-proxy.service reframe-dashboard.service reframe.service || true
sudo systemctl start reframe-dashboard.service
sudo systemctl start reframe-dashboard-proxy.service
sudo systemctl start reframe.service || true
echo
echo "== enabled =="
systemctl is-enabled reframe.service reframe-dashboard.service reframe-dashboard-proxy.service || true
echo
echo "== active =="
systemctl is-active reframe.service reframe-dashboard.service reframe-dashboard-proxy.service || true
echo
echo "== recent reframe logs =="
journalctl -u reframe.service -n 80 --no-pager || true
echo
echo "== dashboard/proxy logs =="
journalctl -u reframe-dashboard.service -n 40 --no-pager || true
journalctl -u reframe-dashboard-proxy.service -n 30 --no-pager || true
'
