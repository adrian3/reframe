#!/bin/bash

# Enable HDR (Wide Dynamic Range) for Raspberry Pi Camera Module 3
# This script sets the wide_dynamic_range control via v4l2-ctl

# Poll for the HDR control instead of paying a fixed sleep. This lets the
# service start early while still handling boots where the camera device appears
# a little later.
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
    # Find the correct camera subdevice
    for dev in /dev/v4l-subdev*; do
        if [ -e "$dev" ]; then
            # Try to set HDR on this device
            if v4l2-ctl --set-ctrl wide_dynamic_range=1 -d "$dev" 2>/dev/null; then
                echo "HDR enabled on $dev"
                logger "Reframe: HDR enabled on $dev"
                exit 0
            fi
        fi
    done

    # Also try the main video device as fallback
    for dev in /dev/video*; do
        if [ -e "$dev" ]; then
            if v4l2-ctl --set-ctrl wide_dynamic_range=1 -d "$dev" 2>/dev/null; then
                echo "HDR enabled on $dev (video device)"
                logger "Reframe: HDR enabled on $dev (video device)"
                exit 0
            fi
        fi
    done

    sleep 0.2
done

echo "HDR control not found; continuing without HDR" >&2
logger "Reframe: HDR control not found; continuing without HDR"
exit 0
