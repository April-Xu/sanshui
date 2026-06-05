#!/bin/bash
# 一键打包发布：build → DMG → GitHub Release → 更新 update.json → push
# 用法: bash release.sh 1.6.0 "更新内容描述"

set -e
cd "$(dirname "$0")"

VERSION="${1:?请传入版本号，例如: bash release.sh 1.6.0 '修复xxx'}"
NOTES="${2:-}"
DMG="build/Sanshui-${VERSION}.dmg"

echo "==> 📦 Build ${VERSION}"
xcodebuild -scheme Sanshui -configuration Release \
  CONFIGURATION_BUILD_DIR="$(pwd)/build/Release" \
  CODE_SIGNING_ALLOWED=NO \
  build -quiet

echo "==> 🖊  Sign"
codesign --force --sign - "build/Release/Sanshui.app" 2>/dev/null || true

echo "==> 💿 Package DMG"
rm -rf build/dmg_staging
mkdir -p build/dmg_staging
cp -r build/Release/Sanshui.app build/dmg_staging/
ln -sf /Applications build/dmg_staging/Applications
hdiutil create -volname "Sanshui" -srcfolder build/dmg_staging \
  -ov -format UDZO "$DMG" -quiet
rm -rf build/dmg_staging
echo "   → $DMG ($(du -sh $DMG | cut -f1))"

echo "==> 🚀 GitHub Release v${VERSION}"
gh release create "v${VERSION}" "$DMG" \
  --repo April-Xu/sanshui \
  --title "Sanshui v${VERSION}" \
  --notes "${NOTES:-版本 ${VERSION}}" 2>&1 | tail -1

echo "==> 📝 update.json"
cat > update.json << EOF
{
  "version": "${VERSION}",
  "url": "https://github.com/April-Xu/sanshui/releases/download/v${VERSION}/Sanshui-${VERSION}.dmg",
  "notes": "${NOTES:-版本 ${VERSION}}"
}
EOF

git add update.json
git commit -m "release: v${VERSION}"
git push origin codex/sanshui-codex-pet

echo ""
echo "✅ 发布完成！用户点「检查更新」即可自动安装 v${VERSION}"
