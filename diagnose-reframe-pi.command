#!/bin/bash
set -e

ssh -t \
  -o UserKnownHostsFile=/tmp/reframe_diag_known_hosts \
  -o StrictHostKeyChecking=accept-new \
  cam@192.168.86.217 \
  'echo "== host ==";
   hostname;
   date;
   echo;
   echo "== services ==";
   systemctl --no-pager status reframe.service reframe-dashboard.service reframe-dashboard-proxy.service || true;
   echo;
   echo "== active states ==";
   systemctl is-enabled reframe.service reframe-dashboard.service reframe-dashboard-proxy.service || true;
   systemctl is-active reframe.service reframe-dashboard.service reframe-dashboard-proxy.service || true;
   echo;
   echo "== reframe logs ==";
   journalctl -u reframe.service -n 120 --no-pager || true;
   echo;
   echo "== dashboard logs ==";
   journalctl -u reframe-dashboard.service -n 120 --no-pager || true;
   echo;
   echo "== proxy logs ==";
   journalctl -u reframe-dashboard-proxy.service -n 80 --no-pager || true;
   echo;
   echo "== listening ports ==";
   ss -ltnp || true'
