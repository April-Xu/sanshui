#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
from pathlib import Path

from PIL import Image

CELL_WIDTH = 192
CELL_HEIGHT = 208
ATLAS_COLUMNS = 8
ATLAS_ROWS = 9
ATLAS_WIDTH = CELL_WIDTH * ATLAS_COLUMNS
ATLAS_HEIGHT = CELL_HEIGHT * ATLAS_ROWS
PET_ID = "sanshui"
DISPLAY_NAME = "Sanshui"
DESCRIPTION = "A pastel coding pet adapted from the Sanshui atlas for Codex custom pets."
ROW_SPECS = [
    ("idle", 0, 6),
    ("running-right", 1, 8),
    ("running-left", 2, 8),
    ("waving", 3, 4),
    ("jumping", 4, 5),
    ("failed", 5, 8),
    ("waiting", 6, 6),
    ("running", 7, 6),
    ("review", 8, 6),
]


def clear_transparent_rgb(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    data = bytearray(rgba.tobytes())
    for index in range(0, len(data), 4):
        if data[index + 3] == 0:
            data[index] = 0
            data[index + 1] = 0
            data[index + 2] = 0
    return Image.frombytes("RGBA", rgba.size, bytes(data))


def save_image(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    normalized = clear_transparent_rgb(image)
    if path.suffix.lower() == ".webp":
        normalized.save(
            path,
            format="WEBP",
            lossless=True,
            quality=100,
            method=6,
            exact=True,
        )
    else:
        normalized.save(path)


def run_command(command: list[str], cwd: Path) -> None:
    subprocess.run(command, cwd=cwd, check=True)


def compose_codex_atlas(source_atlas: Path) -> tuple[Image.Image, dict[str, list[Image.Image]]]:
    atlas = Image.new("RGBA", (ATLAS_WIDTH, ATLAS_HEIGHT), (0, 0, 0, 0))
    row_cells: dict[str, list[Image.Image]] = {}

    with Image.open(source_atlas) as opened:
        source = opened.convert("RGBA")
        for state, row_index, frame_count in ROW_SPECS:
            cells: list[Image.Image] = []
            for column in range(frame_count):
                left = column * CELL_WIDTH
                top = row_index * CELL_HEIGHT
                cell = source.crop((left, top, left + CELL_WIDTH, top + CELL_HEIGHT)).copy()
                cells.append(cell)
                atlas.alpha_composite(cell, (left, row_index * CELL_HEIGHT))
            row_cells[state] = cells

    return atlas, row_cells


def write_pet_request(path: Path, source_atlas: Path) -> None:
    payload = {
        "pet_id": PET_ID,
        "display_name": DISPLAY_NAME,
        "description": DESCRIPTION,
        "source_atlas": str(source_atlas),
        "notes": "Built from the Sanshui atlas rows already mapped to the Codex 9-state contract.",
        "cell": {"width": CELL_WIDTH, "height": CELL_HEIGHT},
        "atlas": {"columns": ATLAS_COLUMNS, "rows": ATLAS_ROWS},
        "row_specs": [
            {"state": state, "row": row, "frame_count": count}
            for state, row, count in ROW_SPECS
        ],
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def write_decoded_rows(decoded_dir: Path, row_cells: dict[str, list[Image.Image]]) -> None:
    decoded_dir.mkdir(parents=True, exist_ok=True)
    for state, _row_index, frame_count in ROW_SPECS:
        strip = Image.new("RGBA", (CELL_WIDTH * frame_count, CELL_HEIGHT), (0, 0, 0, 0))
        for column, cell in enumerate(row_cells[state]):
            strip.alpha_composite(cell, (column * CELL_WIDTH, 0))
        save_image(strip, decoded_dir / f"{state}.png")


def write_frames(frames_root: Path, row_cells: dict[str, list[Image.Image]]) -> None:
    frames_root.mkdir(parents=True, exist_ok=True)
    manifest_rows = []
    for state, _row_index, _frame_count in ROW_SPECS:
        state_dir = frames_root / state
        state_dir.mkdir(parents=True, exist_ok=True)
        outputs = []
        for index, cell in enumerate(row_cells[state]):
            output = state_dir / f"{index:02d}.png"
            save_image(cell, output)
            outputs.append(str(output))
        manifest_rows.append({"state": state, "frames": outputs})

    (frames_root / "frames-manifest.json").write_text(
        json.dumps({"ok": True, "rows": manifest_rows}, indent=2) + "\n",
        encoding="utf-8",
    )


def write_pet_manifest(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(
            {
                "id": PET_ID,
                "displayName": DISPLAY_NAME,
                "description": DESCRIPTION,
                "spritesheetPath": "spritesheet.webp",
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="Build the Sanshui Codex custom pet package.")
    parser.add_argument("--force", action="store_true", help="Remove the existing run/package output.")
    parser.add_argument(
        "--keep-debug",
        action="store_true",
        help="Keep decoded strips, extracted frames, and the intermediate PNG atlas.",
    )
    args = parser.parse_args()

    project_root = Path(__file__).resolve().parents[1]
    repo_root = project_root.parent
    skill_root = Path.home() / ".codex" / "skills" / "hatch-pet"
    source_atlas = repo_root / "Sanshui" / "spritesheet.webp"
    run_dir = project_root / "run"
    decoded_dir = run_dir / "decoded"
    frames_root = run_dir / "frames"
    final_dir = run_dir / "final"
    qa_dir = run_dir / "qa"
    package_dir = project_root / "package"
    codex_pet_dir = Path.home() / ".codex" / "pets" / PET_ID

    if not source_atlas.is_file():
        raise SystemExit(f"missing source atlas: {source_atlas}")
    if not skill_root.is_dir():
        raise SystemExit(f"missing hatch-pet skill: {skill_root}")

    if args.force:
        for path in (run_dir, package_dir, codex_pet_dir):
            if path.exists():
                shutil.rmtree(path)

    final_dir.mkdir(parents=True, exist_ok=True)
    qa_dir.mkdir(parents=True, exist_ok=True)
    package_dir.mkdir(parents=True, exist_ok=True)
    codex_pet_dir.mkdir(parents=True, exist_ok=True)

    atlas, row_cells = compose_codex_atlas(source_atlas)
    write_pet_request(run_dir / "pet_request.json", source_atlas)
    write_decoded_rows(decoded_dir, row_cells)
    write_frames(frames_root, row_cells)
    save_image(atlas, final_dir / "spritesheet.png")
    save_image(atlas, final_dir / "spritesheet.webp")

    run_command(
        [
            "python3",
            str(skill_root / "scripts" / "inspect_frames.py"),
            "--frames-root",
            str(frames_root),
            "--json-out",
            str(qa_dir / "review.json"),
        ],
        project_root,
    )
    run_command(
        [
            "python3",
            str(skill_root / "scripts" / "validate_atlas.py"),
            str(final_dir / "spritesheet.webp"),
            "--json-out",
            str(final_dir / "validation.json"),
        ],
        project_root,
    )
    run_command(
        [
            "python3",
            str(skill_root / "scripts" / "make_contact_sheet.py"),
            str(final_dir / "spritesheet.webp"),
            "--output",
            str(qa_dir / "contact-sheet.png"),
        ],
        project_root,
    )
    run_command(
        [
            "python3",
            str(skill_root / "scripts" / "render_animation_previews.py"),
            "--frames-root",
            str(frames_root),
            "--output-dir",
            str(qa_dir / "previews"),
        ],
        project_root,
    )

    shutil.copy2(final_dir / "spritesheet.webp", package_dir / "spritesheet.webp")
    shutil.copy2(final_dir / "spritesheet.webp", codex_pet_dir / "spritesheet.webp")
    write_pet_manifest(package_dir / "pet.json")
    write_pet_manifest(codex_pet_dir / "pet.json")

    summary = {
        "ok": True,
        "run_dir": str(run_dir),
        "spritesheet": str(final_dir / "spritesheet.webp"),
        "validation": str(final_dir / "validation.json"),
        "contact_sheet": str(qa_dir / "contact-sheet.png"),
        "review": str(qa_dir / "review.json"),
        "package": str(package_dir),
        "codex_pet_dir": str(codex_pet_dir),
    }
    (qa_dir / "run-summary.json").write_text(
        json.dumps(summary, indent=2) + "\n",
        encoding="utf-8",
    )

    if not args.keep_debug:
        if decoded_dir.exists():
            shutil.rmtree(decoded_dir)
        if frames_root.exists():
            shutil.rmtree(frames_root)
        png_atlas = final_dir / "spritesheet.png"
        if png_atlas.exists():
            png_atlas.unlink()

    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
