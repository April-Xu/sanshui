#!/bin/bash
# 打包 Sanshui 为 .dmg 分发包
# 使用方式: ./scripts/build_dmg.sh [version]
# 注意：项目已改名 Sanshui，但 scheme/target 仍叫 QoderPet

set -e

VERSION=${1:-"1.0.0"}
APP_NAME="QoderPet"       # Xcode scheme/target 名
DMG_DISPLAY="Sanshui"     # DMG 卷名和文件名
BUILD_DIR="build"
DMG_NAME="${DMG_DISPLAY}-${VERSION}.dmg"

echo "==> 构建 ${DMG_DISPLAY} v${VERSION}"

# 1. 用 xcodebuild build 直接输出 .app（保留 AppIcon.icns 等 Resources）
xcodebuild \
  -project "Sanshui.xcodeproj" \
  -scheme "${APP_NAME}" \
  -configuration Release \
  CONFIGURATION_BUILD_DIR="$(pwd)/${BUILD_DIR}/Release" \
  build

APP_PATH="${BUILD_DIR}/Release/${APP_NAME}.app"

# 2. 创建 DMG（带 Applications 软链接）
echo "==> 创建 DMG..."
mkdir -p "${BUILD_DIR}/dmg_staging"
cp -r "${APP_PATH}" "${BUILD_DIR}/dmg_staging/"
ln -sf /Applications "${BUILD_DIR}/dmg_staging/Applications"

hdiutil create \
  -volname "${DMG_DISPLAY}" \
  -srcfolder "${BUILD_DIR}/dmg_staging" \
  -ov \
  -format UDZO \
  "${BUILD_DIR}/${DMG_NAME}"

rm -rf "${BUILD_DIR}/dmg_staging"

echo "==> 完成！输出: ${BUILD_DIR}/${DMG_NAME}"
echo "==> 分享这个文件给用户，双击挂载后拖到 Applications 即可安装"
