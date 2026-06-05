# SanshuiCodexPet

把 `/Users/miaojunxu/Documents/Claude/Projects/Sanshui/Sanshui/spritesheet.webp` 里的 Codex 主状态行导出为可直接安装的 `Codex custom pet`。

这个项目保留原 atlas 的格位和动作节奏，不重新缩放或重居中 frame。输出同时写到：

- `SanshuiCodexPet/package/`
- `${HOME}/.codex/pets/sanshui/`

## 行映射

源 atlas 是 `12 x 11`，每格 `192 x 208`。这个项目只取 Codex 需要的 `8 x 9` 主状态区：

| Codex state | 源 row | 使用列 |
| --- | ---: | ---: |
| `idle` | 0 | 6 |
| `running-right` | 1 | 8 |
| `running-left` | 2 | 8 |
| `waving` | 3 | 4 |
| `jumping` | 4 | 5 |
| `failed` | 5 | 8 |
| `waiting` | 6 | 6 |
| `running` | 7 | 6 |
| `review` | 8 | 6 |

说明：

- 我沿用了现有 `Sanshui` App 里的状态映射，所以实际导出的是前 9 个 Codex 主状态行。
- 源图里更下面的扩展动作行不会进入最终 `Codex custom pet` 包。

## 构建

```bash
cd /Users/miaojunxu/Documents/Claude/Projects/Sanshui
python3 SanshuiCodexPet/scripts/build_pet.py --force
```

如需保留中间调试文件：

```bash
python3 SanshuiCodexPet/scripts/build_pet.py --force --keep-debug
```

## 产物

- `SanshuiCodexPet/run/final/spritesheet.webp`
- `SanshuiCodexPet/run/final/validation.json`
- `SanshuiCodexPet/run/qa/contact-sheet.png`
- `SanshuiCodexPet/run/qa/previews/*.gif`
- `SanshuiCodexPet/package/pet.json`
- `SanshuiCodexPet/package/spritesheet.webp`

## 备注

`build_pet.py` 会清理 transparent RGB residue，保证 `validate_atlas.py` 能通过透明像素校验。
