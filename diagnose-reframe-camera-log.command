#!/bin/bash
set -e

ssh -t \
  -o UserKnownHostsFile=/tmp/reframe_diag_known_hosts \
  -o StrictHostKeyChecking=accept-new \
  cam@192.168.86.217 \
  'echo "== service status ==";
   systemctl --no-pager --full status reframe.service || true;
   echo;
   echo "== boot logs for reframe.service ==";
   journalctl -b -u reframe.service -n 260 --no-pager || true;
   echo;
   echo "== quick python import check ==";
   cd /home/cam/reframe;
   python3 - <<'"'"'PY'"'"'
import aiofiles, fastapi, httpx, numpy, PIL, qrcode, smbus2, uvicorn
import gpiozero, picamera2
print("imports ok")
PY'
