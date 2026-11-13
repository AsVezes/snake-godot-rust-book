import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tools.run_checks import Step, build_plan, main, run_plan


class VerificationRunnerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "rust").mkdir()
        (self.root / "godot").mkdir()
        (self.root / "rust" / "Cargo.toml").write_text("[package]\nname='example'\n")
        (self.root / "godot" / "project.godot").write_text("config_version=5\n")

    def test_plan_has_four_rust_steps_first(self):
        plan = build_plan(self.root)
        self.assertEqual(len(plan), 6)
        self.assertEqual([s.name for s in plan[:4]], ["Rust format check", "Rust unit tests", "Rust lints", "Build native extension"])
        self.assertEqual(plan[0].args, ("cargo", "fmt", "--all", "--", "--check"))
        self.assertEqual(plan[3].args, ("cargo", "build"))

    def test_full_plan_uses_user_selected_godot_binary(self):
        plan = build_plan(self.root, "/opt/godot")
        self.assertEqual(plan[-2].args[0], "/opt/godot")
        self.assertEqual(plan[-1].args[-1], "res://SmokeTest.gd")

    def test_rust_only_keeps_four_steps(self):
        plan = build_plan(self.root, rust_only=True)
        self.assertEqual(len(plan), 4)
        self.assertFalse(any("Godot" in s.name for s in plan))

    def test_missing_manifest_is_configuration_error(self):
        (self.root / "rust" / "Cargo.toml").unlink()
        with self.assertRaises(FileNotFoundError):
            build_plan(self.root)

    def test_stops_on_first_nonzero_exit(self):
        steps = build_plan(self.root)
        with patch("tools.run_checks.subprocess.run") as run:
            run.return_value = subprocess.CompletedProcess([], 3)
            self.assertEqual(run_plan(steps), 3)
            self.assertEqual(run.call_count, 1)

    def test_reports_missing_binary(self):
        with patch("tools.run_checks.subprocess.run", side_effect=FileNotFoundError("cargo")):
            self.assertEqual(run_plan(build_plan(self.root)), 2)

    def test_reports_permission_error(self):
        with patch("tools.run_checks.subprocess.run", side_effect=PermissionError("no access")):
            self.assertEqual(run_plan(build_plan(self.root)), 2)

    def test_times_out(self):
        with patch("tools.run_checks.subprocess.run", side_effect=subprocess.TimeoutExpired("cargo", 1)):
            self.assertEqual(run_plan(build_plan(self.root), 1), 124)

    def test_all_commands_success(self):
        steps = build_plan(self.root)
        with patch("tools.run_checks.subprocess.run") as run:
            run.return_value = subprocess.CompletedProcess([], 0)
            self.assertEqual(run_plan(steps), 0)
            self.assertEqual(run.call_count, len(steps))

    def test_nonpositive_timeout_rejected(self):
        with self.assertRaises(ValueError):
            run_plan([], 0)

    def test_cli_rejects_nonpositive_timeout(self):
        with self.assertRaises(SystemExit) as err:
            main(["--timeout-seconds", "0"])
        self.assertEqual(err.exception.code, 2)


if __name__ == "__main__":
    unittest.main()
