# QoderPet — 阿里 Qoder 桌面宠物

## 项目结构

```
QoderPet/
├── QoderPetApp.swift        # 入口，状态栏菜单
├── PetWindowController.swift # 透明悬浮窗口
├── PetViewController.swift   # 动画播放 + 漫步逻辑
├── PetState.swift            # 状态枚举 + spritesheet 行映射
├── SpriteSheetParser.swift   # 从 spritesheet 裁剪帧
├── QoderStateMonitor.swift   # 监听 Qoder 运行状态
└── Resources/
    └── spritesheet.webp      # 你的 spritesheet（放到 Assets.xcassets 里）
```

## 快速开始

1. 新建 macOS App 项目（Xcode → macOS → App，Interface: SwiftUI）
2. 把所有 `.swift` 文件拖入项目
3. 把 `spritesheet.webp` 拖入 `Assets.xcassets`，命名为 `spritesheet`
4. 替换 `Info.plist` 内容（关键：`LSUIElement=true` 隐藏 Dock 图标）
5. 删除 Xcode 默认生成的 `ContentView.swift`

## Spritesheet 行映射

在 `PetState.swift` 的 `animationConfig` 里调整行号和帧数：

| 状态 | 当前行 | 帧数 |
|------|--------|------|
| idle | 0 | 6 |
| walking (右) | 1 | 8 |
| walking (左) | 2 | 8 |
| thinking | 3 | 4 |
| coding | 4 | 5 |
| success/celebrate | 7 | 6 |
| error/tired | 6 | 8 |
| sunburn (预留) | 9 | 8 |

## 状态监听方式

### 当前：进程 CPU 监听
`QoderStateMonitor` 默认用 `ps aux` 检测 Qoder 进程的 CPU 使用率：
- 0%  → idle
- 5–30% → thinking
- 30–70% → coding（生成中）

### 扩展：HTTP API 轮询
如果 Qoder 暴露了本地 API，把 `useProcessMonitor = false`，
填入 `qoderAPIURL`，返回格式：
```json
{ "status": "thinking" | "generating" | "success" | "error" | "idle" }
```

### 手动测试
状态栏菜单 → "手动切换状态" 可直接触发任意动画。

## 调整 Spritesheet 解析

当前项目使用 `8×10` atlas，最后一行预留给 `sunburn`。如果你后面改了列数/行数，再修改 `PetViewController.swift` 里：
```swift
spriteParser = SpriteSheetParser(imageName: "spritesheet", columns: 8, rows: 10)
```
