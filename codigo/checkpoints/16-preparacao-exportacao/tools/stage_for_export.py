#!/usr/bin/env python3
"""Stage a SELF-CONTAINED CP16 Godot project for a later manual export.

This tool does NOT compile Rust, run Godot, export an executable, or install
export templates. Header checks reject obvious wrong-format artifacts but do
not verify dependencies, ABI, signatures, platform support or safety.
"""
from __future__ import annotations

import argparse
from pathlib import Path
import shutil
import tempfile

if __package__:
    from .binary_format import verify_native_binary
else:
    from binary_format import verify_native_binary

LIBRARIES = {
    "linux": ("librenda_snake_step16.so", "linux.x86_64"),
    "windows": ("renda_snake_step16.dll", "windows.x86_64"),
    "macos": ("librenda_snake_step16.dylib", "macos"),
}
GODOT_FILES = (
    "project.godot",
    "Main.tscn",
    "Board.gd",
    "HighScoreStore.gd",
    "ScoreHud.gd",
    "SmokeTest.gd",
    "SignalRecorder.gd",
)


def stage_checkpoint(
    root: Path,
    platform: str,
    profile: str = "release",
    native_binary: Path | None = None,
) -> Path:
    if platform not in LIBRARIES:
        raise ValueError(f"Unsupported platform: {platform}")
    if profile not in ("debug", "release"):
        raise ValueError(f"Unsupported profile: {profile}")
    root = root.resolve()
    filename, tags = LIBRARIES[platform]
    source = (native_binary if native_binary is not None
              else root / "rust" / "target" / profile / filename).resolve()
    if not source.is_file():
        raise FileNotFoundError(f"Native library missing: {source}")
    verify_native_binary(source, platform)
    godot_root = root / "godot"
    for name in GODOT_FILES:
        if not (godot_root / name).is_file():
            raise FileNotFoundError(f"Godot source missing: {godot_root / name}")

    destination = root / "out" / f"snake-step16-{platform}-{profile}"
    if destination.exists():
        raise FileExistsError(f"Staging destination already exists: {destination}")
    destination.parent.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(
        prefix=".partial-step16-", dir=destination.parent
    ) as temporary:
        staging = Path(temporary)
        for name in GODOT_FILES:
            shutil.copy2(godot_root / name, staging / name)
        library_dir = staging / "bin"
        library_dir.mkdir()
        shutil.copy2(source, library_dir / filename)
        # One selected native binary is used for both feature profiles.
        # This is teaching staging, not proof of debug/release parity.
        key = tags.split(".")
        tag_suffix = f".{key[1]}" if len(key) > 1 else ""
        descriptor = (
            "[configuration]\n"
            'entry_symbol = "gdext_rust_init"\n'
            "compatibility_minimum = 4.4\n"
            "reloadable = false\n\n"
            "[libraries]\n"
            f'{key[0]}.debug{tag_suffix} = "res://bin/{filename}"\n'
            f'{key[0]}.release{tag_suffix} = "res://bin/{filename}"\n'
        )
        (staging / "Snake.gdextension").write_text(descriptor, encoding="utf-8")
        gd_cache = staging / ".godot"
        gd_cache.mkdir()
        (gd_cache / "extension_list.cfg").write_text(
            "res://Snake.gdextension\n", encoding="utf-8"
        )
        # A preset is deliberately NOT invented. Godot must create and verify it.
        if destination.exists():
            raise FileExistsError(f"Staging destination appeared: {destination}")
        staging.rename(destination)
    return destination


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--platform", required=True, choices=sorted(LIBRARIES))
    parser.add_argument("--profile", choices=("debug", "release"), default="release")
    parser.add_argument("--native-binary", type=Path,
                        help="Optional library from a target-specific Cargo directory")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    try:
        staged = stage_checkpoint(root, args.platform, args.profile, args.native_binary)
    except (ValueError, FileNotFoundError, FileExistsError) as exc:
        parser.error(str(exc))
    print(f"STAGED_ONLY: {staged}")
    print("NOT EXPORTED: install Godot templates, create a preset and test on target OS.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
