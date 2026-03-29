# WallpaperColor

A native macOS menu bar app that reads the current wallpaper, extracts its dominant and average color, and sends them to **Home Assistant** (via webhook) and/or an **MQTT broker** — continuously and in the background.

> **Note:** This app was developed with the assistance of [Claude](https://claude.ai) (Anthropic AI).
> The author is not a professional programmer. The code works well in practice but comes without any guarantee of correctness. Use at your own risk.

---

## Features

- **Dominant & average color extraction** using a Median-Cut quantization algorithm
- **5-zone analysis** — center, top, bottom, left, right (optional)
- **Smooth color transitions** — interpolates between old and new color over a configurable duration
- **Home Assistant webhook** integration
- **MQTT** publish support (no external library — pure `Network.framework`)
- **Dynamic menu bar icon** — small color dot shows the current dominant color at a glance
- **Screensaver & screen lock detection** — optionally pause when the screen is inactive
- **Wake-from-sleep** — triggers an immediate color check when the Mac wakes up
- **Launch at Login** toggle (via `SMAppService`)
- Lightweight — no Python, no Electron, no external dependencies

---

## Requirements

- macOS 13 Ventura or later
- [Xcode 16+](https://developer.apple.com/xcode/) (to build from source)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- A running Home Assistant instance and/or MQTT broker (optional)

---

## Build & Install

```bash
git clone https://github.com/YOUR_USERNAME/WallpaperColor.git
cd WallpaperColor
xcodegen generate
xcodebuild -scheme WallpaperColorApp \
  -destination 'platform=macOS' \
  -configuration Release \
  CODE_SIGN_IDENTITY="-" \
  build
```

Copy the built `.app` to `/Applications`:

```bash
cp -R ~/Library/Developer/Xcode/DerivedData/WallpaperColorApp-*/Build/Products/Release/WallpaperColor.app /Applications/
open /Applications/WallpaperColor.app
```

**First launch:** macOS will show a security warning because the app is not notarized.
Right-click → Open, or run:

```bash
xattr -d com.apple.quarantine /Applications/WallpaperColor.app
```

---

## Home Assistant Setup

### 1. Create a webhook automation

In Home Assistant, go to **Settings → Automations → New Automation** and use this trigger:

```yaml
trigger:
  - platform: webhook
    webhook_id: YOUR_WEBHOOK_ID
    allowed_methods:
      - POST
```

Enter the same `YOUR_WEBHOOK_ID` in the app's Settings window under **Webhook-ID**.

The webhook payload contains:

```json
{
  "wallpaper_farbe_durchschnitt": "#A3B2C1",
  "wallpaper_farbe_dominant":     "#2F4A6B"
}
```

With **5-zone analysis** enabled, additional fields are included:

```json
{
  "wallpaper_farbe_durchschnitt": "#A3B2C1",
  "wallpaper_farbe_dominant":     "#2F4A6B",
  "zone_mitte":  "#1E3A5F",
  "zone_oben":   "#C8D4DF",
  "zone_unten":  "#3D2B1F",
  "zone_links":  "#8899AA",
  "zone_rechts": "#4A6070"
}
```

### 2. Example: Control a light with the dominant color

```yaml
action:
  - service: light.turn_on
    target:
      entity_id: light.wohnzimmer
    data:
      rgb_color: >
        {% set hex = trigger.json.wallpaper_farbe_dominant | replace('#','') %}
        [{{ range(0,2) | map('int') | list }}]
```

---

## MQTT Setup

Enable MQTT in the Settings window and configure:

| Setting | Example |
|---|---|
| Broker Host | `homeassistant.local` |
| Port | `1883` |
| Topic | `wallpaper/color` |
| Username / Password | optional |

**Payload** (JSON, published on every change):

```json
{
  "average":      "#A3B2C1",
  "dominant":     "#2F4A6B",
  "zone_center":  "#1E3A5F",
  "zone_top":     "#C8D4DF",
  "zone_bottom":  "#3D2B1F",
  "zone_left":    "#8899AA",
  "zone_right":   "#4A6070"
}
```

Zone fields are only included when **5-zone analysis** is enabled.

---

## Settings Overview

| Setting | Description |
|---|---|
| HA Host | Home Assistant address, e.g. `homeassistant.local:8123` |
| Poll Interval | How often to check for wallpaper changes (5–300 s) |
| MQTT | Enable MQTT publishing alongside or instead of the webhook |
| Smooth Transition | Interpolate colors over 0.5–5 s when the wallpaper changes |
| 5-Zone Analysis | Analyze 5 regions of the wallpaper separately |
| Pause on Screensaver | Stop polling while the screensaver is active |
| Pause on Screen Lock | Stop polling while the screen is locked |
| Launch at Login | Start automatically when you log in |

---

## Project Structure

```
WallpaperColorApp/
├── project.yml                        # XcodeGen config
├── WallpaperColorApp/
│   ├── App/
│   │   ├── WallpaperColorApp.swift    # @main, MenuBarExtra, dynamic icon
│   │   └── Info.plist
│   ├── Services/
│   │   ├── WallpaperCapture.swift     # CGImage from wallpaper file / CGWindowList
│   │   ├── ColorAnalyzer.swift        # Average, dominant, zones, hash
│   │   ├── WallpaperService.swift     # Polling loop, screensaver/lock/wake handling
│   │   ├── HAWebhook.swift            # HTTP POST to HA webhook
│   │   ├── MQTTPublisher.swift        # Minimal MQTT 3.1.1 client (no deps)
│   │   ├── SettingsManager.swift      # AppSettings (Codable, stored as JSON)
│   │   └── ScreensaverMonitor.swift   # DistributedNotificationCenter events
│   ├── Views/
│   │   ├── MenuBarView.swift          # Dropdown menu
│   │   └── SettingsView.swift         # Settings window
│   └── Utils/
│       ├── ColorPickerController.swift # NSColorPanel wrapper
│       ├── ColorInterpolator.swift     # Linear RGB interpolation
│       └── LaunchAtLoginManager.swift  # SMAppService wrapper
```

---

## How It Works

1. Every N seconds (configurable), the app reads the wallpaper image from disk using `NSWorkspace.desktopImageURL`. For slideshow wallpapers, it falls back to capturing the Dock's wallpaper window via `CGWindowListCreateImage`.
2. A 20×20 pixel thumbnail MD5 hash detects whether the wallpaper has actually changed — no unnecessary sends.
3. Colors are extracted: average (100×100 resize) and dominant (Median-Cut on 150×150).
4. Colors are sent to HA webhook and/or MQTT.

---

## AI Disclosure

This project was written entirely with the assistance of **Claude** (claude.ai, by Anthropic).
The author provided requirements and direction; all Swift code was generated by the AI.

This is disclosed transparently because:
- The author does not have full expertise to review every implementation detail
- AI-generated code can contain subtle bugs or non-idiomatic patterns
- Users should be aware when evaluating the code for security-sensitive use cases

Contributions and code reviews are very welcome.

---

## License

MIT — see [LICENSE](LICENSE)
