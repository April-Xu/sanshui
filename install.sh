#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Sanshui"
INSTALL_DIR="$HOME/Applications"
APP_DEST="$INSTALL_DIR/$APP_NAME.app"

echo "🐾 $APP_NAME 安装程序"
echo "========================"

# 检查 Xcode
if ! xcodebuild -version &>/dev/null; then
    echo "❌ 需要安装 Xcode，请从 App Store 安装后重试"
    exit 1
fi

# 切换 xcode-select 指向 Xcode.app（如果当前指向 CLT）
if [[ "$(xcode-select -p)" == *"CommandLineTools"* ]]; then
    echo "🔧 切换 xcode-select 到 Xcode.app..."
    sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
fi

echo "🔨 编译中（首次约需 30 秒）..."
cd "$SCRIPT_DIR"
xcodebuild \
    -project QoderPet.xcodeproj \
    -scheme QoderPet \
    -configuration Release \
    build \
    CONFIGURATION_BUILD_DIR="$SCRIPT_DIR/build/Release" \
    -quiet 2>&1 | grep -E "error:|warning:|BUILD" || true

BUILD_APP="$SCRIPT_DIR/build/Release/QoderPet.app"
if [ ! -d "$BUILD_APP" ]; then
    echo "❌ 编译失败，请检查 Xcode 是否正确安装"
    exit 1
fi
echo "✅ 编译完成"

# 停掉旧版本
pkill -x QoderPet 2>/dev/null || pkill -x "$APP_NAME" 2>/dev/null || true
sleep 0.5

# 安装到 ~/Applications（不需要 sudo，且不触发 Gatekeeper）
mkdir -p "$INSTALL_DIR"
rm -rf "$APP_DEST"
cp -r "$BUILD_APP" "$APP_DEST"
echo "📦 已安装到 $APP_DEST"

# 注册开机自启（通过 launchd）
PLIST_DIR="$HOME/Library/LaunchAgents"
PLIST_PATH="$PLIST_DIR/com.sanshui.app.plist"
mkdir -p "$PLIST_DIR"
cat > "$PLIST_PATH" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>Label</key><string>com.sanshui.app</string>
    <key>ProgramArguments</key><array><string>$APP_DEST/Contents/MacOS/QoderPet</string></array>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><false/>
</dict></plist>
PLIST
launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"
echo "🚀 已注册开机自启"

# 启动
open "$APP_DEST"

echo ""
echo "========================"
echo "🎉 安装完成！"
echo "   Peachy 已出现在屏幕右下角"
echo "   右键 Peachy → 退出"
echo "   卸载：bash uninstall.sh"
