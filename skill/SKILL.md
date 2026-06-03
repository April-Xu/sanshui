---
name: install-sanshui
description: Install Sanshui desktop pet for Qoder. Builds from source and registers login item. Use when the user wants to install, update, or uninstall the Sanshui/QoderPet desktop pet.
---

# Install Sanshui — Qoder Desktop Pet

Sanshui is a desktop pet that floats on screen and reacts to Qoder's working state.

## Prerequisites check

Before doing anything, verify:
1. macOS (this is macOS-only)
2. Xcode installed (`xcodebuild -version`)

If Xcode is missing, tell the user to install it from the App Store and stop.

## Install steps

### 1. Find the source zip

The zip is bundled with this skill at:
```
<skill_dir>/Sanshui-source.zip
```

Where `<skill_dir>` is the directory containing this SKILL.md file.

### 2. Extract

```bash
SKILL_DIR="$(dirname "$0")"  # directory of this skill
WORK_DIR="$HOME/.sanshui_build"
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
unzip -q "$SKILL_DIR/Sanshui-source.zip" -d "$WORK_DIR"
```

### 3. Fix xcode-select if needed

```bash
if [[ "$(xcode-select -p 2>/dev/null)" == *"CommandLineTools"* ]]; then
    sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
fi
```

### 4. Build

```bash
cd "$WORK_DIR"
xcodebuild \
    -project QoderPet.xcodeproj \
    -scheme QoderPet \
    -configuration Release \
    CONFIGURATION_BUILD_DIR="$WORK_DIR/build" \
    build -quiet
```

If build fails, report the error and stop.

### 5. Stop old version

```bash
pkill -x QoderPet 2>/dev/null || true
pkill -x Sanshui 2>/dev/null || true
sleep 0.5
```

### 6. Install to ~/Applications

```bash
mkdir -p "$HOME/Applications"
rm -rf "$HOME/Applications/Sanshui.app"
cp -r "$WORK_DIR/build/QoderPet.app" "$HOME/Applications/Sanshui.app"
```

### 7. Register login item (auto-start with macOS)

```bash
PLIST="$HOME/Library/LaunchAgents/com.sanshui.app.plist"
cat > "$PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>Label</key><string>com.sanshui.app</string>
    <key>ProgramArguments</key><array><string>$HOME/Applications/Sanshui.app/Contents/MacOS/QoderPet</string></array>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><false/>
</dict></plist>
EOF
launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"
```

### 8. Launch

```bash
open "$HOME/Applications/Sanshui.app"
```

### 9. Clean up build files

```bash
rm -rf "$WORK_DIR"
```

### 10. Confirm success

Tell the user: "Sanshui 已安装并启动！Sanshui 出现在屏幕右下角。右键 Sanshui 可退出。"

---

## Uninstall steps

If the user wants to uninstall:

```bash
pkill -x QoderPet 2>/dev/null || true
launchctl unload ~/Library/LaunchAgents/com.sanshui.app.plist 2>/dev/null || true
rm -f ~/Library/LaunchAgents/com.sanshui.app.plist
rm -rf ~/Applications/Sanshui.app
```

Tell the user: "Sanshui 已卸载。"

---

## Update steps

Uninstall first, then install fresh from the zip.
