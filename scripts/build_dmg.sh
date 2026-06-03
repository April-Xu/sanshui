#!/bin/bash
# 打包 QoderPet 为 .dmg 分发包
# 使用方式: ./scripts/build_dmg.sh [version]

set -e

VERSION=${1:-"1.0.0"}
APP_NAME="QoderPet"
BUILD_DIR="build"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"

echo "==> 构建 ${APP_NAME} v${VERSION}"

# 1. 用 xcodebuild 编译
xcodebuild \
  -project "${APP_NAME}.xcodeproj" \
  -scheme "${APP_NAME}" \
  -configuration Release \
  -archivePath "${BUILD_DIR}/${APP_NAME}.xcarchive" \
  archive

# 2. 导出 .app
xcodebuild \
  -exportArchive \
  -archivePath "${BUILD_DIR}/${APP_NAME}.xcarchive" \
  -exportOptionsPlist "scripts/ExportOptions.plist" \
  -exportPath "${BUILD_DIR}/export"

APP_PATH="${BUILD_DIR}/export/${APP_NAME}.app"

# 3. 如果有开发者证书，进行公证（可选，没证书跳过）
# codesign --force --deep --sign "Developer ID Application: Your Name (TEAMID)" "${APP_PATH}"
# xcrun notarytool submit "${APP_PATH}" --apple-id "your@email.com" --password "@keychain:AC_PASSWORD" --team-id "TEAMID" --wait

# 4. 创建 DMG
echo "==> 创建 DMG..."
mkdir -p "${BUILD_DIR}/dmg_staging"
cp -r "${APP_PATH}" "${BUILD_DIR}/dmg_staging/"

# 创建 Applications 软链接
ln -sf /Applications "${BUILD_DIR}/dmg_staging/Applications"

hdiutil create \
  -volname "${APP_NAME}" \
  -srcfolder "${BUILD_DIR}/dmg_staging" \
  -ov \
  -format UDZO \
  "${BUILD_DIR}/${DMG_NAME}"

rm -rf "${BUILD_DIR}/dmg_staging"

echo "==> 完成！输出: ${BUILD_DIR}/${DMG_NAME}"
echo "==> 分享这个文件给用户，双击挂载后拖到 Applications 即可安装"
