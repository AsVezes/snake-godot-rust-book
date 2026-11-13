"""Isolated CP16 staging tests; fake ELF headers are NOT loadable libraries."""
from __future__ import annotations

from pathlib import Path
import struct
import tempfile
import unittest

from tools.stage_for_export import GODOT_FILES, stage_checkpoint


def fake_elf64_x86_64() -> bytes:
    data = bytearray(64)
    data[:4] = bytes((127,)) + b"ELF"
    data[4] = 2
    data[5] = 1
    struct.pack_into("<HH", data, 16, 3, 62)
    return bytes(data)


class StageForExportTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        source = self.root / "godot"
        source.mkdir()
        for name in GODOT_FILES:
            (source / name).write_text("fixture: " + name, encoding="utf-8")
        self.binary = self.root / "rust/target/release/librenda_snake_step16.so"
        self.binary.parent.mkdir(parents=True)
        self.binary.write_bytes(fake_elf64_x86_64())

    def test_stages_every_required_resource_and_native_descriptor(self) -> None:
        out = stage_checkpoint(self.root, "linux", "release")
        for name in GODOT_FILES:
            self.assertEqual((out / name).read_text(encoding="utf-8"),
                             "fixture: " + name)
        self.assertEqual((out / "bin/librenda_snake_step16.so").read_bytes(),
                         fake_elf64_x86_64())
        descriptor = (out / "Snake.gdextension").read_text(encoding="utf-8")
        self.assertIn('linux.release.x86_64 = "res://bin/librenda_snake_step16.so"', descriptor)
        self.assertIn('linux.debug.x86_64 = "res://bin/librenda_snake_step16.so"', descriptor)
        self.assertNotIn("res://../rust", descriptor)
        self.assertFalse((out / "export_presets.cfg").exists())
        self.assertTrue((out / "ScoreHud.gd").is_file())
        self.assertTrue((out / "HighScoreStore.gd").is_file())

    def test_does_not_overwrite_staging_folder(self) -> None:
        stage_checkpoint(self.root, "linux")
        with self.assertRaises(FileExistsError):
            stage_checkpoint(self.root, "linux")

    def test_missing_native_library_is_reported(self) -> None:
        self.binary.unlink()
        with self.assertRaises(FileNotFoundError):
            stage_checkpoint(self.root, "linux")

    def test_wrong_binary_format_is_rejected(self) -> None:
        self.binary.write_bytes(b"not an ELF library")
        with self.assertRaises(ValueError):
            stage_checkpoint(self.root, "linux")

    def test_missing_score_hud_blocks_incomplete_package(self) -> None:
        (self.root / "godot/ScoreHud.gd").unlink()
        with self.assertRaises(FileNotFoundError):
            stage_checkpoint(self.root, "linux")

    def test_explicit_binary_from_target_directory(self) -> None:
        other = self.root / "cross-build/librenda_snake_step16.so"
        other.parent.mkdir()
        other.write_bytes(fake_elf64_x86_64())
        self.binary.unlink()
        output = stage_checkpoint(self.root, "linux", native_binary=other)
        self.assertTrue((output / "bin/librenda_snake_step16.so").is_file())


if __name__ == "__main__":
    unittest.main()
