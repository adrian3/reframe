# reFrame Camera — Setup Handoff

Context for picking up this project. The working repo is at `~/Desktop/reframe` (cloned from https://github.com/kaloyaan/reframe, now diverged from upstream — see changes below).

## Build deviation from stock instructions

This build powers the Raspberry Pi Zero 2 W directly (plain USB/battery power) instead of through a PiSugar 3 board. That removes PiSugar's hardware power-on, hardware long-press shutdown, and battery monitoring. To compensate, a physical momentary push button was wired directly to the Pi's GPIO for photo capture:

- Button leg 1 → **GPIO4** (physical pin 7 on the 40-pin header)
- Button leg 2 → **GND** (physical pin 9, adjacent to pin 7)
- No external resistor — code enables the Pi's internal pull-up, so idle = HIGH, pressed = LOW.

Optional shutdown warning buzzer:

- Buzzer `+` / signal → **GPIO23** (physical pin 16)
- Buzzer `-` / GND → **GND** (physical pin 14 is nearby)
- Current settings use the buzzer for a shutter click on capture, a warning one minute before the 10-minute inactivity shutdown, and a shutdown cadence before long-press or inactivity shutdown.
- Use a small active 3.3V buzzer or a low-current piezo. If the buzzer draws more than a few milliamps, drive it with a transistor instead of directly from the GPIO pin.

## Code changes already made (local repo, not pushed upstream)

**`reframe.py`** — in `main()`, the PiSugar I2C button-read block was replaced with a direct GPIO read:
- Removed: `smbus2` I2C read from PiSugar register `0x02` at address `0x57`.
- Added: `gpiozero.Button(4, pull_up=True, bounce_time=0.02)`, with `is_power_button_pressed()` now just returning `shutter_button.is_pressed`.
- The existing short-press (capture) / long-press (ignore) polling loop below it was untouched — it only calls `is_power_button_pressed()`, so no other logic needed to change.
- `finally: bus.close()` → `finally: shutter_button.close()`.
- `gpiozero` needed no new dependency — it's already used by `waveshare_epd/epdconfig.py` for the display, so it's present on the Pi already.

**`install.sh`** — Step 3 ("PiSugar Power Manager") was replaced with a no-op that just logs a warning and skips it, since there's no PiSugar hardware to detect. Everything else in the script (system packages, SPI/I2C enable via `raspi-config`, boot-speed trims, systemd services, user groups) is unmodified and still needed — SPI is still required for the e-ink display, and the `gpio` group (already added by `usermod` in the script) covers permission for GPIO4.

**Camera/display processing** — this build is currently configured for Raspberry Pi Camera Module V2 / NoIR V2 (`imx219`):
- Boot config should use `camera_auto_detect=0` and `dtoverlay=imx219`.
- Capture defaults are `3280×2464`, the full Camera Module V2 still resolution.
- Original JPEGs are saved at full capture resolution.
- The dithered display image keeps the full `2464px` source height, center-crops width to about `1643px`, resizes that portrait crop to `400×600`, then rotates it `-90°` to the final `600×400` dithered image. This loses more width than the previous landscape crop but preserves full height.

Nothing else in the codebase hard-depends on PiSugar: `dashboard.py`'s `/api/battery` endpoint calls `nc` to `127.0.0.1:8423` and gracefully returns `battery_level: None` if `pisugar-server` isn't running (dashboard just shows `--%`), and `reframe.service` has no `Requires=`/`After=` on `pisugar-server.service`.

## Current status

SD card is flashed (Raspberry Pi OS Lite, hostname `reframe`, user `cam`), the Pi is wired up with the camera, e-ink display, and the direct GPIO button, and it was booting for the first time as of this handoff. SSH has not yet been used to install the software on the Pi itself — the local repo on the Mac has the code changes above, but that code has not yet been transferred to the Pi.

## Remaining steps

Run from the user's own Mac terminal (an assistant needs actual local-network/SSH access to the Pi to do this — a sandboxed environment without LAN access cannot reach `reframe.local`):

```bash
# 1. SSH in (password is whatever was set in Raspberry Pi Imager)
ssh cam@reframe.local

# 2. From a separate terminal window (not the SSH session), copy the
#    locally-modified repo to the Pi — do NOT git clone from GitHub,
#    that would pull the vanilla version without the GPIO button change
rsync -av --exclude='.git' ~/Desktop/reframe/ cam@reframe.local:~/reframe/

# 3. Back in the SSH session, install
cd ~/reframe
chmod +x install.sh
./install.sh
# It will print that it's skipping PiSugar, then proceed normally.
# Say yes when it prompts to reboot.
```

After reboot, verify:

```bash
# Watch for capture events while pressing the button
sudo journalctl -u reframe.service -f
# Should log "Short press detected... capturing photo" on press

# If the button seems unresponsive, sanity-check the pin directly
python3 -c "from gpiozero import Button; b=Button(4); print('press now...'); [print(b.is_pressed) for _ in range(100)]"
# Should print True while held
```

Dashboard: `http://reframe.local` (fallback `http://reframe.local:8000`). Battery will show `--%` since there's no PiSugar — expected.

## WiFi priority

The live Pi is using NetworkManager. It has two WiFi profiles:

- `iphone-hotspot` — SSID `Ade’s iPhone 17 Pro`, autoconnect priority `100`
- `netplan-wlan0-Area53` — home WiFi fallback, autoconnect priority `10`

The hotspot password is stored only in NetworkManager on the Pi, not in this repo. A boot helper, `reframe-prefer-phone-wifi.service`, scans for several minutes after networking starts and switches to `iphone-hotspot` if the phone SSID is visible; otherwise it leaves Area53 or any other current connection alone.

On a fresh SD card, add the phone network with:

```bash
sudo nmcli connection add type wifi ifname wlan0 con-name iphone-hotspot ssid "Ade’s iPhone 17 Pro"
sudo nmcli connection modify iphone-hotspot \
  connection.autoconnect yes \
  connection.autoconnect-priority 100 \
  connection.autoconnect-retries -1 \
  wifi-sec.key-mgmt wpa-psk \
  wifi-sec.psk "<iphone hotspot password>"
sudo nmcli connection modify netplan-wlan0-Area53 \
  connection.autoconnect yes \
  connection.autoconnect-priority 10 \
  connection.autoconnect-retries -1
sudo systemctl enable reframe-prefer-phone-wifi.service
```

On the iPhone, keep **Personal Hotspot → Allow Others to Join** enabled when using the camera outside. If the Pi does not see the hotspot, enable **Maximize Compatibility** so the hotspot is available in a Pi Zero-friendly 2.4 GHz mode.

If the Pi still does not see the hotspot, unlock the iPhone and leave **Settings → Personal Hotspot** open while powering on the camera. iPhones sometimes stop advertising the hotspot aggressively when no device is connected.

## Known non-issue

Long-press-to-shutdown is implemented in software: hold the GPIO4 shutter button for at least 2 seconds, release, and reFrame plays the shutdown cadence on GPIO23 before running `sudo shutdown -h now`. The 10-minute inactivity auto-shutdown also remains enabled. After shutdown, powering the camera back on still means unplugging/replugging power because this direct-power build has no PiSugar-style hardware wake circuit.
