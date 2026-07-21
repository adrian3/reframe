# Software Setup

How to set up a reFrame camera from scratch.

## 1. Flash the SD Card

Download and install [Raspberry Pi Imager](https://www.raspberrypi.com/software/). Insert a microSD card into your computer and flash it with the following settings:

- **OS:** Raspberry Pi OS Lite (32-bit)
- **Hostname:** `reframe`
- **Username:** `cam`
- **Password:** your choice (but write it down somewhere safe)
- **WiFi:** enter your home network name and password. If you want to use the camera on the go, also add your phone's hotspot (you can add multiple networks)
- **Services:** Enable SSH with password authentication

Eject the card, insert it into the Pi Zero 2 W, and power it on. On a new
PiSugar 3, the first power-on may require a short press followed by a long
press. The reFrame installer disables this accidental-touch prevention mode so
later power-ons use a single press.

### Raspberry Pi OS Version

The reference build currently uses Raspberry Pi OS Lite 32-bit. Bullseye is the most tested target for this repo because it was the first Raspberry Pi OS release with the libcamera/Picamera2 stack that Camera Module 3 depends on, and early Zero 2 W camera support had some version-specific rough edges.

Bookworm should be possible now: current Raspberry Pi Picamera2 documentation supports Bullseye or later, and Bookworm uses the same modern libcamera/Picamera2 direction.

## 2. SSH into the Pi

Once the Pi has booted (give it a minute), connect from your computer:

```bash
ssh cam@reframe.local
```

Enter the password you set in the imager.

## 3. Install reFrame

```bash
git clone https://github.com/kaloyaan/reframe.git
cd reframe
chmod +x install.sh
./install.sh
```

The script installs all system and Python dependencies, enables I2C/SPI/camera interfaces, installs PiSugar Power Manager if it is missing, configures PiSugar one-press power-on, applies the headless boot-speed settings, sets up the systemd services, and creates the photo directories. It will prompt you to reboot when done.

If the official PiSugar installer asks you to select a model, choose **PiSugar 3**. After installation:

- `pisugar-server` runs as a systemd service and starts on boot
- Battery level is available via TCP on port `8423` (the dashboard reads this automatically)
- Power management web UI is at `http://reframe.local:8421`

By default, PiSugar 3 ships with accidental-touch prevention enabled. In that mode, power-on requires a short press followed by a long press. reFrame disables that mode during installation so the camera behaves like this:

- **single press while off** = power on
- **startup** = automatically take and display one photo
- **single press while on** = take a new photo
- **long press while on** = shut down
- **10 minutes of inactivity** = automatic shutdown to prevent battery drain

The installer applies this with the PiSugar Power Manager command `set_anti_mistouch false`. If you installed PiSugar after running `install.sh`, run the reFrame installer again, or apply the setting manually:

```bash
echo "set_anti_mistouch false" | nc -q 0 127.0.0.1 8423
```

You can check the current setting with:

```bash
echo "get anti_mistouch" | nc -q 0 127.0.0.1 8423
```

> **Note:** reFrame reads the button directly via I2C (address `0x57`) for photo capture. PiSugar still handles battery monitoring, one-press power-on, and long-press shutdown.

### PiSugar RTC

The installer keeps the Raspberry Pi system clock and the PiSugar 3 real-time clock in UTC. reFrame synchronizes them automatically on startup: it syncs the system clock from the RTC, and whenever network time becomes available it updates both clocks.

## 4. Reboot

```bash
sudo reboot
```

After rebooting, reFrame starts automatically. The camera takes a photo on startup, sends it to the ePaper screen, then saves the original JPEG and dithered PNG in the background.

---

## Dashboard

![reFrame dashboard showing the photo gallery and camera controls](images/reframe-dashboard.webp)

Open a browser on any device connected to the same network:

```
http://reframe.local
```

The dashboard lets you browse photos, download originals, change the displayed image, and adjust camera settings.

The dashboard also remains available on port 8000 as a fallback:

```
http://reframe.local:8000
```

If you used a different Pi hostname during Raspberry Pi Imager setup, replace `reframe` with that hostname.

Dashboard settings include a software update button for git-based installs. It checks the configured upstream repo, installs fast-forward updates only, preserves ignored user data such as your settings and photos, refreshes dependencies and service files, and asks you to reboot after a successful update.

### Using with a Phone Hotspot

To use the camera without a WiFi network, enable your phone's hotspot. As long as you added the hotspot name and password during flashing (step 1), the Pi will connect to it automatically on boot.

On iPhone, you can find your hotspot name under Settings → General → About → Name. Enable **Maximize Compatibility** in hotspot settings for the Pi to connect reliably.

Whenever the camera connects or reconnects to WiFi, it shows a dashboard QR code on the ePaper display. The network watcher remains active after startup, and the QR encodes the numeric IP when one is available so it also works on hotspots that do not resolve `.local` hostnames. This behavior is enabled by default and can be disabled under system settings in the dashboard.

On Android/Pixel hotspots, `.local` hostnames may not resolve reliably. In that case, use the QR code's numeric IP URL, for example `http://192.168.x.x`.

## HDR (Camera Module 3)

HDR is automatically enabled at startup via `scripts/enable_hdr.sh` after Python imports finish but before Picamera2 opens the camera. This overlaps camera-device discovery with Python startup. To control it manually:

```bash
# Enable
v4l2-ctl --set-ctrl wide_dynamic_range=1 -d /dev/v4l-subdev0

# Disable
v4l2-ctl --set-ctrl wide_dynamic_range=0 -d /dev/v4l-subdev0
```

HDR + autofocus make a big difference on the ePaper display.

## Photo Formats And Capture Flow

reFrame captures the startup/button photo into memory first so the image can be dithered and sent to the ePaper display quickly. It then saves files in the background:

- Original camera captures are saved as JPEGs for faster capture and smaller files.
- The display/dashboard dithered version is saved as a PNG so the 6-color dithered image stays crisp.
- Immediately after a capture, the dashboard may take a moment to show the newest files while the background save finishes.

By default, reFrame shuts down automatically after 10 minutes without button, dashboard, or display activity to avoid draining the PiSugar battery. You can change this in `settings.json` with `system.auto_timeout_minutes` and `system.auto_timeout_enabled`.

## Other Displays Or Cameras

The reference build uses Raspberry Pi Camera Module 3, PiSugar 3, and a Waveshare 4" Spectra 6 ePaper HAT, but the hardware-specific code is intentionally isolated in `CameraManager`, `EInkDisplay`, and the small button block in `reframe.py`.

See [Hardware Porting Notes](hardware-porting.md) for adapting the repo for Pimoroni, Good Display, another camera module, or a different button/power board.

## Upload Extensions

The dashboard can show optional per-photo upload buttons. Extensions are off by default and run on the dashboard server so API tokens are not sent back to the browser.

The built-in Are.na extension uploads the dithered PNG of a photo. Enable it from dashboard settings by entering an Are.na channel slug/id and an access token with write access. The token field is write-only: leave it blank to keep the saved token, enter a new token to replace it, or use the clear-token button to remove it.

Example Are.na channel: [Shot on reFrame](https://www.are.na/kalo/shot-on-reframe).

See [Dashboard Extensions](dashboard-extensions.md) for the full Are.na flow and notes on adding your own upload extension.

## Service Commands

```bash
sudo systemctl status reframe.service      # check status
sudo journalctl -u reframe.service -f      # view logs
sudo systemctl restart reframe.service     # restart
sudo systemctl stop reframe.service        # stop
```

---

## Manual Install

If you prefer to set things up by hand, here's what the install script does:

### System Packages

```bash
sudo apt update
sudo apt install -y python3-pip python3-picamera2 python3-spidev \
    python3-gpiozero v4l-utils i2c-tools netcat-openbsd wget
```

### PiSugar Power Manager

```bash
wget https://cdn.pisugar.com/release/pisugar-power-manager.sh
bash pisugar-power-manager.sh -c release
echo "set_anti_mistouch false" | nc -q 0 127.0.0.1 8423
```

Select **PiSugar 3** if prompted by the PiSugar installer.

### Python Packages

```bash
pip3 install -r requirements.txt
```

### Enable Hardware Interfaces

```bash
sudo raspi-config nonint do_i2c 0
sudo raspi-config nonint do_spi 0
```

The camera should be auto-detected. If not, add `camera_auto_detect=1` to your boot config:
- **Bullseye:** `/boot/config.txt`
- **Bookworm:** `/boot/firmware/config.txt`

### User Permissions

```bash
sudo usermod -a -G video,i2c,spi,gpio cam
```

Log out and back in for changes to take effect.

### Configuration

```bash
cp settings.example.json settings.json
```

### Systemd Services

```bash
sudo cp systemd/reframe.service /etc/systemd/system/
sudo cp systemd/reframe-dashboard.service /etc/systemd/system/
sudo cp systemd/reframe-dashboard-proxy.service /etc/systemd/system/
sudo cp systemd/reframe-rtc-restore.service /etc/systemd/system/
sudo cp systemd/reframe-rtc-update.service /etc/systemd/system/
sudo install -o root -g root -m 0755 scripts/reframe-rtc-sync /usr/local/sbin/reframe-rtc-sync
sudo install -d -o root -g root -m 0755 /var/lib/reframe
sudo timedatectl set-timezone UTC
sudo timedatectl set-ntp true
sudo systemctl daemon-reload
sudo systemctl reenable reframe.service
sudo systemctl enable reframe-dashboard.service reframe-dashboard-proxy.service reframe-rtc-restore.service reframe-rtc-update.service
sudo reboot
```

### Boot-Speed Settings

The camera service selects the `ondemand` CPU governor when the host supports it. This lets capture and image processing use the Pi's full clock under load while returning to its lower idle clock between photos.

The installer optimizes for fastest boot-to-first-photo while keeping WiFi, SSH, mDNS, PiSugar, and camera capture working.

It writes these headless hardware settings to the Pi boot config (`/boot/config.txt` on Bullseye, `/boot/firmware/config.txt` on Bookworm):

```bash
dtoverlay=disable-bt
dtparam=audio=off
hdmi_blanking=2
boot_delay=0
camera_auto_detect=1
display_auto_detect=0
disable_splash=1
disable_poe_fan=1
force_eeprom_read=0
enable_tvout=0
```

It also disables services and timers that are not needed for a headless camera:

```bash
sudo systemctl disable --now \
  ModemManager.service \
  triggerhappy.service triggerhappy.socket \
  udisks2.service rsync.service rpi-eeprom-update.service \
  networking.service keyboard-setup.service console-setup.service \
  rsyslog.service \
  bluetooth.service hciuart.service bluealsa.service \
  apt-daily.timer apt-daily-upgrade.timer man-db.timer \
  e2scrub_all.timer fstrim.timer
```

Do **not** disable these for the normal camera build:

```bash
ssh.service
wpa_supplicant.service
dhcpcd.service
avahi-daemon.service
pisugar-server.service
reframe.service
reframe-dashboard.service
reframe-dashboard-proxy.service
```

On the reference Pi Zero 2 W, these changes plus the in-memory capture path reduced app-level startup capture-to-display dispatch to under 1 second once Picamera2 is ready. A cold boot still includes OS, HDR, Python import, and libcamera startup time; the ePaper display refresh itself still takes about 20 seconds to physically finish, and that is expected.

To undo the service trims, re-enable only what you need, for example:

```bash
sudo systemctl enable --now bluetooth.service hciuart.service
```

---

## Troubleshooting

**Camera not detected**
- Verify the ribbon cable is seated properly on both ends
- Check: `libcamera-hello --list-cameras`
- Ensure `cam` is in the `video` group: `groups cam`

**Display not updating**
- Confirm SPI is enabled: `sudo raspi-config nonint get_spi` (should return `0`)
- Check physical connections between the display HAT and Pi header
- Review logs: `sudo journalctl -u reframe.service`

**Button not responding**
- Confirm I2C is enabled: `sudo raspi-config nonint get_i2c` (should return `0`)
- Check: `sudo i2cdetect -y 1` (should show a device at address `57` for PiSugar)

**Service won't start**
- The service files expect the repo at `/home/cam/reframe`
- Check: `sudo systemctl status reframe.service`
- View full logs: `sudo journalctl -u reframe.service --no-pager`
