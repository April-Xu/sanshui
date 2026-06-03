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
  - `custom-sunburn/`：`sunburn` 的独立 strip、sprite、GIF 和 QA

- `hatch-pet-skill/`
  这次精灵图工作流依赖的规则与脚本，包含：
  - `SKILL.md`
  - `references/`：状态语义、contract、QA 规则
  - `scripts/`：prepare、extract、compose、validate、preview 等脚本

## 现在的重要事实

- 主 `spritesheet.webp` 还是 Codex 官方 9 状态 atlas。
- `sunburn` 目前已经做成独立 sprite，放在：
  `/Users/miaojunxu/Documents/Claude/Projects/QoderPet/PeachySpriteWorkshop/peachy-run/custom-sunburn/`
- 如果后面要把 `sunburn` 真正塞进 App 在用的主 atlas，还需要决定替换哪个现有状态位。

## GitHub

- 本地仓库路径：
  `/Users/miaojunxu/Documents/Claude/Projects/QoderPet`
- 当前已经连到远端：
  `origin = https://github.com/April-Xu/qoder-pet.git`

