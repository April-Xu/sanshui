# PeachySpriteWorkshop

这个文件夹是 `Peachy` 精灵图的完整工作包，后续继续改图、补动作、重打包时，优先从这里开始。

## 当前主精灵图更新目标

- App 使用位置：
  `/Users/miaojunxu/Documents/Claude/Projects/QoderPet/QoderPet/spritesheet.webp`
- 我已经把当前主 atlas 同步覆盖到这个位置。

## 文件夹结构

- `runtime-pet/`
  当前 Codex pet 打包结果，包含：
  - `pet.json`
  - `spritesheet.webp`

- `peachy-run/`
  当前这只 pet 的实际生成工作区，包含：
  - `prompts/`：主 atlas 各 row 的提示词
  - `references/`：canonical base、layout guide 等参考图
  - `decoded/`：各 row 的生成 strip
  - `frames/`、`frames-stable/`：切出来的逐帧 PNG
  - `final/`、`final-stable/`：打包后的 atlas
  - `qa/`、`qa-stable/`：contact sheet、GIF 预览、校验产物
  - `custom-sunburn/`：旧版 `sunburn` 工作区，仅保留作历史参考
  - `custom-sunburn-v2/`：当前 App 使用的两条 12 帧扩展 row、sprite、GIF 和 QA

- `hatch-pet-skill/`
  这次精灵图工作流依赖的规则与脚本，包含：
  - `SKILL.md`
  - `references/`：状态语义、contract、QA 规则
  - `scripts/`：prepare、extract、compose、validate、preview 等脚本

## 现在的重要事实

- App 主 `spritesheet.webp` 当前为 `12×11` atlas，每格仍为 `192×208`。
- 原有 9 个状态保留在 `row 0-8` 的前 8 格。
- `row 9` 是 `sunburn-shy`，`row 10` 是 `sunburn-swim`，两行各 12 帧。
- 当前扩展动作工作区：
  `/Users/miaojunxu/Documents/Claude/Projects/QoderPet/PeachySpriteWorkshop/peachy-run/custom-sunburn-v2/`

## GitHub

- 本地仓库路径：
  `/Users/miaojunxu/Documents/Claude/Projects/QoderPet`
- 当前已经连到远端：
  `origin = https://github.com/April-Xu/qoder-pet.git`
