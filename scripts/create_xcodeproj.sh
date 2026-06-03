#!/bin/bash
# 用 Swift Package Manager 生成基础结构（不依赖手动 Xcode 操作）
# 但 macOS app 最终还是需要 Xcode，这个脚本帮你验证环境

echo "==> 检查开发环境"

# Xcode Command Line Tools
if ! xcode-select -p &>/dev/null; then
  echo "[!] 未安装 Xcode Command Line Tools，正在安装..."
  xcode-select --install
  echo "    安装完成后重新运行此脚本"
  exit 1
fi
echo "[✓] Xcode CLT: $(xcode-select -p)"

# Xcode
if ! /usr/bin/xcodebuild -version &>/dev/null; then
  echo "[!] 未安装 Xcode，请从 App Store 安装"
  open "https://apps.apple.com/app/xcode/id497799835"
  exit 1
fi
echo "[✓] Xcode: $(/usr/bin/xcodebuild -version | head -1)"

# Swift
echo "[✓] Swift: $(swift --version 2>&1 | head -1)"

echo ""
echo "==> 环境检查通过！"
echo "==> 下一步：在 Xcode 中新建项目"
echo "    1. File → New → Project"
echo "    2. macOS → App"
echo "    3. Product Name: QoderPet"
echo "    4. Interface: SwiftUI"
echo "    5. 把 QoderPet/ 目录下的 .swift 文件拖入项目"
echo "    6. 把 spritesheet.webp 拖入 Assets.xcassets，命名 spritesheet"
