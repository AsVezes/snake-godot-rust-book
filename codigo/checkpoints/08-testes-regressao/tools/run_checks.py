"""Run checkpoint 08's Rust/Godot checks without invoking a shell.

Run from any directory: python3 tools/run_checks.py
"""
from __future__ import annotations

import argparse
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Step:
    name: str
    args: tuple[str, ...]
    cwd: Path


def build_plan(root: Path, godot_executable: str = "godot", rust_only: bool = False) -> list[Step]:
    rust = root / "rust"
    godot = root / "godot"
    if not (rust / "Cargo.toml").is_file():
        raise FileNotFoundError(f"Rust manifest missing: {rust / 'Cargo.toml'}")
    if not (godot / "project.godot").is_file():
        raise FileNotFoundError(f"Godot project missing: {godot / 'project.godot'}")

    plan = [
        Step("Rust format check", ("cargo", "fmt", "--all", "--", "--check"), rust),
        Step("Rust unit tests", ("cargo", "test"), rust),
        Step("Rust lints", ("cargo", "clippy", "--all-targets", "--", "-D", "warnings"), rust),
        Step("Build native extension", ("cargo", "build"), rust),
    ]
    if not rust_only:
        plan.extend([
            Step("Import Godot resources", (godot_executable, "--headless", "--path", "godot", "--import"), root),
            Step("Run Godot integration smoke", (godot_executable, "--headless", "--path", "godot", "--script", "res://SmokeTest.gd"), root),
        ])
    return plan


def run_plan(plan: list[Step], timeout_seconds: float = 180.0) -> int:
    if timeout_seconds <= 0:
        raise ValueError("timeout_seconds must be positive")
    for index, step in enumerate(plan, start=1):
        print(f"[{index}/{len(plan)}] {step.name}: {' '.join(step.args)}", flush=True)
        try:
            result = subprocess.run(list(step.args), cwd=step.cwd, timeout=timeout_seconds, check=False)
        except FileNotFoundError as exc:
            print(f"FAIL missing command: {exc}", file=sys.stderr)
            return 2
        except PermissionError as exc:
            print(f"FAIL cannot execute command: {exc}", file=sys.stderr)
            return 2
        except subprocess.TimeoutExpired:
            print(f"FAIL timeout after {timeout_seconds:g}s: {step.name}", file=sys.stderr)
            return 124
        if result.returncode != 0:
            print(f"FAIL exit {result.returncode}: {step.name}", file=sys.stderr)
            return result.returncode
    print("CHECKPOINT_08_CHECKS_OK: all selected tools completed successfully")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Run Rust and Godot verification for teaching checkpoint 08")
    parser.add_argument("--godot-executable", default="godot", help="Path or command name for the Godot editor")
    parser.add_argument("--rust-only", action="store_true", help="Skip Godot checks (not a complete validation)")
    parser.add_argument("--timeout-seconds", type=float, default=180.0, help="Maximum seconds per external command")
    args = parser.parse_args(argv)
    if args.timeout_seconds <= 0:
        parser.error("--timeout-seconds must be positive")
    root = Path(__file__).resolve().parents[1]
    try:
        plan = build_plan(root, args.godot_executable, args.rust_only)
    except FileNotFoundError as exc:
        print(f"FAIL configuration: {exc}", file=sys.stderr)
        return 2
    return run_plan(plan, args.timeout_seconds)


if __name__ == "__main__":
    raise SystemExit(main())
