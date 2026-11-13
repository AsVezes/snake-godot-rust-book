"""Check Godot+Rust Snake book checkpoints; show live output and save evidence.

Every PASS requires real exit codes. --dry-run and --rust-only are explicit.
Only Python standard library is needed to orchestrate commands.
"""
from __future__ import annotations

import argparse
from collections import deque
import json
import os
import platform
import shutil
import signal
import subprocess
import sys
import threading
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

STAGES = (
    "01-cenas-e-nos", "02-ciclo-e-grade", "03-primeira-gdextension",
    "04-cobra-estatica", "05-regras-rust", "06-integracao-movimento",
    "07-pausa-foco-idiomas", "08-testes-regressao", "09-recorde-em-arquivo", "10-sqlite-historico",
    "11-ranking-local", "12-migracoes-sqlite",
    "13-ownership-e-gameview",
    "14-sinais-e-hud",
    "15-laboratorio-desempenho",
    "16-preparacao-exportacao",
)


@dataclass(frozen=True)
class Step:
    label: str
    command: tuple[str, ...]
    cwd: Path


def parse_stages(value: str) -> list[int]:
    selected = []
    for piece in value.split(","):
        try:
            number = int(piece.strip())
        except ValueError as exc:
            raise ValueError(f"Invalid stage: {piece!r}") from exc
        if number < 1 or number > len(STAGES):
            raise ValueError(f"Stage outside 1..{len(STAGES)}: {number}")
        if number not in selected:
            selected.append(number)
    if not selected:
        raise ValueError("Select at least one checkpoint")
    return selected


def detect_godot(explicit: str | None = None) -> str:
    """Pick the binary; do not guess a Flatpak command or installation path."""
    if explicit:
        return explicit
    for candidate in ("godot", "godot4"):
        if shutil.which(candidate):
            return candidate
    return "godot"  # failure must be reported, never silently skipped


def plan(root: Path, stage_number: int, cargo: str, godot: str, *, rust_only: bool = False) -> list[Step]:
    if stage_number < 1 or stage_number > len(STAGES):
        raise ValueError(f"Unknown stage {stage_number}")
    folder = root / STAGES[stage_number - 1]
    if rust_only and stage_number < 3:
        return []  # stages 01/02 contain no Rust; they are not PASS
    if not (folder / "godot" / "project.godot").is_file():
        raise FileNotFoundError(f"Missing Godot project: {folder}")
    steps: list[Step] = []
    if stage_number >= 8:
        if not (folder / "tools" / "tests" / "test_run_checks.py").is_file():
            raise FileNotFoundError(f"Missing Python tests: {folder}")
        steps.append(Step("Python runner tests", (sys.executable, "-m", "unittest", "discover", "-s", "tools/tests", "-v"), folder))
    if stage_number >= 3:
        if not (folder / "rust" / "Cargo.toml").is_file():
            raise FileNotFoundError(f"Missing Cargo.toml: {folder}")
        rust = folder / "rust"
        steps.extend((
            Step("Rust format", (cargo, "fmt", "--all", "--", "--check"), rust),
            Step("Rust tests", (cargo, "test"), rust),
            Step("Rust Clippy", (cargo, "clippy", "--all-targets", "--", "-D", "warnings"), rust),
            Step("Rust native library", (cargo, "build"), rust),
        ))
    if not rust_only:
        steps.append(Step("Godot import", (godot, "--headless", "--path", "godot", "--import"), folder))
        if stage_number >= 6:
            if not (folder / "godot" / "SmokeTest.gd").is_file():
                raise FileNotFoundError(f"Missing Godot smoke test: {folder}")
            steps.append(Step("Godot integration smoke", (godot, "--headless", "--path", "godot", "--script", "res://SmokeTest.gd"), folder))
        else:
            steps.append(Step("Godot scene launch", (godot, "--headless", "--path", "godot", "--quit-after", "5"), folder))
    return steps


def stop_process(process: subprocess.Popen) -> None:
    """Stop a command and its children on POSIX, then reap it."""
    if process.poll() is not None:
        return
    try:
        if os.name == "posix":
            os.killpg(process.pid, signal.SIGTERM)
        else:
            process.terminate()
        process.wait(timeout=3)
    except (OSError, subprocess.TimeoutExpired):
        if process.poll() is None:
            try:
                if os.name == "posix":
                    os.killpg(process.pid, signal.SIGKILL)
                else:
                    process.kill()
            except OSError:
                pass
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                pass


def execute(steps: list[Step], timeout: float) -> tuple[str, list[dict]]:
    """Stream every line to the terminal while retaining a short JSON log tail."""
    results: list[dict] = []
    for step in steps:
        print(f"  RUN {step.label}: {' '.join(step.command)}", flush=True)
        detail: dict = {"step": step.label, "command": list(step.command), "cwd": str(step.cwd)}
        try:
            proc = subprocess.Popen(
                step.command, cwd=step.cwd,
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                text=True, errors="replace", bufsize=1,
                start_new_session=(os.name == "posix"),
            )
        except (FileNotFoundError, PermissionError, OSError) as exc:
            detail["error"] = f"{type(exc).__name__}: {exc}"
            results.append(detail)
            print(f"  BLOCKED {step.label}: {exc}", file=sys.stderr)
            return "BLOCKED", results

        tail: deque[str] = deque(maxlen=120)

        def forward_output() -> None:
            assert proc.stdout is not None
            for line in proc.stdout:
                print(line, end="", flush=True)
                tail.append(line)

        reader = threading.Thread(target=forward_output, daemon=True)
        reader.start()
        try:
            code = proc.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            stop_process(proc)
            detail["error"] = f"TimeoutExpired: exceeded {timeout:g} seconds"
            detail["output_tail"] = "".join(tail)[-2500:]
            results.append(detail)
            print(f"  BLOCKED {step.label}: timed out after {timeout:g}s", file=sys.stderr)
            return "BLOCKED", results
        except KeyboardInterrupt:
            stop_process(proc)
            detail["error"] = "KeyboardInterrupt: stopped by user"
            detail["output_tail"] = "".join(tail)[-2500:]
            results.append(detail)
            print(f"  INTERRUPTED {step.label}: partial report will be saved", file=sys.stderr)
            return "INTERRUPTED", results
        finally:
            reader.join(timeout=3)

        detail["exit_code"] = code
        detail["output_tail"] = "".join(tail)[-2500:]
        results.append(detail)
        if code != 0:
            print(f"  FAIL {step.label}: exit {code}", file=sys.stderr)
            return "FAIL", results
        print(f"  PASS {step.label}", flush=True)
    return "PASS", results


def main(argv: list[str] | None = None, *, root: Path | None = None) -> int:
    cli = argparse.ArgumentParser(description="Check the cumulative Snake book checkpoints")
    cli.add_argument("--stages", default="1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16", help="Comma-separated checkpoint numbers")
    cli.add_argument("--cargo", default="cargo", help="Cargo executable or absolute path")
    cli.add_argument("--godot", default=None, help="Godot binary; default autodetects godot or godot4")
    cli.add_argument("--rust-only", action="store_true", help="Check Rust/Python only; skip Godot (incomplete QA)")
    cli.add_argument("--timeout-seconds", type=float, default=600.0, help="Per-command time limit")
    cli.add_argument("--dry-run", action="store_true", help="Print commands only; no tests executed")
    cli.add_argument("--report", type=Path, help="Optional local JSON report path")
    args = cli.parse_args(argv)
    if args.timeout_seconds <= 0:
        cli.error("--timeout-seconds must be positive")
    try:
        stage_numbers = parse_stages(args.stages)
    except ValueError as exc:
        cli.error(str(exc))
    base = root if root is not None else Path(__file__).resolve().parent.parent / "checkpoints"
    godot_binary = detect_godot(args.godot)
    report = {"generated_at_utc": datetime.now(timezone.utc).isoformat(),
              "system": platform.platform(), "python": sys.version.split()[0],
              "dry_run": args.dry_run, "rust_only": args.rust_only,
              "godot_command": godot_binary, "stages": []}
    failed = False
    interrupted = False
    for number in stage_numbers:
        item = {"checkpoint": STAGES[number - 1], "number": number}
        try:
            steps = plan(base, number, args.cargo, godot_binary, rust_only=args.rust_only)
        except (FileNotFoundError, ValueError) as exc:
            item.update(status="BLOCKED", reason=str(exc), checks=[])
            failed = True
            print(f"[{number:02d}] BLOCKED: {exc}", file=sys.stderr)
        else:
            print(f"[{number:02d}] {STAGES[number - 1]}", flush=True)
            if not steps:
                item.update(status="SKIPPED_NO_RUST", checks=[])
                print("  SKIPPED_NO_RUST: this checkpoint only contains Godot")
            elif args.dry_run:
                for step in steps:
                    print(f"  PLANNED {' '.join(step.command)}  (cwd={step.cwd})")
                item.update(status="PLANNED_NOT_TESTED", checks=[])
            else:
                status, checks = execute(steps, args.timeout_seconds)
                recorded_status = "PASS_RUST_ONLY" if args.rust_only and status == "PASS" else status
                item.update(status=recorded_status, checks=checks)
                failed |= status != "PASS"
                interrupted = status == "INTERRUPTED"
        report["stages"].append(item)
        if interrupted:
            break
    if interrupted:
        for number in stage_numbers[len(report["stages"]):]:
            report["stages"].append({"checkpoint": STAGES[number - 1],
                                     "number": number, "status": "NOT_RUN_AFTER_INTERRUPT", "checks": []})
    if args.report:
        try:
            args.report.parent.mkdir(parents=True, exist_ok=True)
            args.report.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
            print(f"Report: {args.report}", flush=True)
        except OSError as exc:
            print(f"Cannot save report: {exc}", file=sys.stderr)
            return 2
    counts = {s: sum(x["status"] == s for x in report["stages"])
              for s in ("PASS", "PASS_RUST_ONLY", "FAIL", "BLOCKED", "INTERRUPTED", "PLANNED_NOT_TESTED",
                        "SKIPPED_NO_RUST", "NOT_RUN_AFTER_INTERRUPT")}
    print(f"Summary: {counts}")
    return 130 if interrupted else (1 if failed else 0)


if __name__ == "__main__":
    raise SystemExit(main())
