---
name: install-sanshui-codex-pet
description: Install, refresh, export, or remove the Sanshui Codex custom pet from bundled assets. Use when another Codex agent needs a portable skill bundle that can install the Sanshui pet into `${CODEX_HOME:-$HOME/.codex}/pets/sanshui`.
---

# Install Sanshui Codex Pet

Use this skill when the user wants to reuse the Sanshui custom pet in another Codex setup.

The bundled pet files live under:

```text
<skill_dir>/assets/pet/
```

Where `<skill_dir>` is the directory containing this `SKILL.md`.

## Install

Run:

```bash
SKILL_DIR="/absolute/path/to/install-sanshui-codex-pet"
bash "$SKILL_DIR/scripts/install.sh"
```

What this does:

- copies the bundled `pet.json` and `spritesheet.webp`
- installs them to `${CODEX_HOME:-$HOME/.codex}/pets/sanshui/`
- creates a timestamped backup if a `sanshui` pet already exists

After install, tell the user to restart the `Codex desktop app` so the pet list reloads.

## Verify

Check:

```bash
ls -la "${CODEX_HOME:-$HOME/.codex}/pets/sanshui"
cat "${CODEX_HOME:-$HOME/.codex}/pets/sanshui/pet.json"
```

Expected files:

- `pet.json`
- `spritesheet.webp`

## Uninstall

Run:

```bash
SKILL_DIR="/absolute/path/to/install-sanshui-codex-pet"
bash "$SKILL_DIR/scripts/uninstall.sh"
```

This removes `${CODEX_HOME:-$HOME/.codex}/pets/sanshui`.

## Export

If the user only wants the raw pet assets, copy:

```text
<skill_dir>/assets/pet/pet.json
<skill_dir>/assets/pet/spritesheet.webp
```

directly into:

```text
${CODEX_HOME:-$HOME/.codex}/pets/sanshui/
```
