#!/bin/bash
# 快速开发循环：build → 杀掉旧进程 → 启动新版本
set -e
cd "$(dirname "$0")"

echo "🔨 Building..."
xcodebuild -scheme Sanshui -configuration Debug \
  CONFIGURATION_BUILD_DIR="$(pwd)/build/Debug" \
  CODE_SIGNING_ALLOWED=NO \
  build -quiet

echo "🔄 Restarting..."
pkill -x Sanshui 2>/dev/null || true
sleep 0.3
open build/Debug/Sanshui.app
echo "✅ Done"
