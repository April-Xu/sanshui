#!/bin/bash
echo "🗑  卸载 Sanshui..."
pkill -x Sanshui 2>/dev/null || true
launchctl unload ~/Library/LaunchAgents/com.sanshui.app.plist 2>/dev/null || true
rm -f ~/Library/LaunchAgents/com.sanshui.app.plist
rm -rf ~/Applications/Sanshui.app
echo "✅ 已卸载"
