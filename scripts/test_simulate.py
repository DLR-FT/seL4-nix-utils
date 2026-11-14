#!/usr/bin/env python3
"""Build and execute all QEMU-simulatable targets outside the Nix build sandbox."""

from __future__ import annotations

import argparse
import codecs
import os
import signal
import subprocess
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

RESET = "\033[0m"
BOLD = "\033[1m"
DIM = "\033[2m"
RED = "\033[31m"
GREEN = "\033[32m"
CYAN = "\033[36m"


@dataclass(frozen=True)
class SimSpec:
    target: str
    pass_markers: tuple[str, ...]
    fail_markers: tuple[str, ...] = ()


SIM_SPECS: tuple[SimSpec, ...] = (
    SimSpec(
        target=".#seL4-test-armv7l-zynq7000-simulate",
        pass_markers=("Test suite passed.",),
        fail_markers=("Test suite failed.",),
    ),
    SimSpec(
        target=".#seL4-test-i686-ia32-simulate",
        pass_markers=("Test suite passed.",),
        fail_markers=("Test suite failed.",),
    ),
    SimSpec(
        target=".#seL4-test-riscv32-spike-simulate",
        pass_markers=("Test suite passed.",),
        fail_markers=("Test suite failed.",),
    ),
    SimSpec(
        target=".#seL4-test-riscv64-spike-simulate",
        pass_markers=("Test suite passed.",),
        fail_markers=("Test suite failed.",),
    ),
    SimSpec(
        target=".#seL4-test-x86_64-x86_64-simulate",
        pass_markers=("Test suite passed.",),
        fail_markers=("Test suite failed.",),
    ),
    SimSpec(
        target=".#seL4-camkes-vm-examples-aarch64-qemu-arm-virt",
        pass_markers=("buildroot login:",),
        fail_markers=("Kernel panic",),
    ),
)


@dataclass
class SimResult:
    target: str
    passed: bool
    duration_s: float
    reason: str
    tail: list[str]


def build_target(target: str, cores: int, max_jobs: int) -> Path:
    cmd = [
        "nix",
        "build",
        "--cores",
        str(cores),
        "--max-jobs",
        str(max_jobs),
        "--no-link",
        "--print-out-paths",
        target,
    ]
    proc = subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True)
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip())
    return Path(proc.stdout.strip().splitlines()[-1])


def kill_process_group(pid: int) -> None:
    for sig in (signal.SIGTERM, signal.SIGKILL):
        try:
            os.killpg(pid, sig)
        except ProcessLookupError:
            return
        time.sleep(0.1)


def run_sim(spec: SimSpec, out_dir: Path, timeout_s: int, verbose: bool) -> SimResult:
    start = time.monotonic()
    sim_bin = out_dir / "simulate"
    if not sim_bin.is_file() or not os.access(sim_bin, os.X_OK):
        return SimResult(
            target=spec.target,
            passed=False,
            duration_s=time.monotonic() - start,
            reason=f"missing executable {sim_bin}",
            tail=[],
        )

    proc = subprocess.Popen(
        [str(sim_bin)],
        cwd="/tmp",
        env={"PATH": "/nonexistent"},
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        bufsize=0,
        start_new_session=True,
    )

    timed_out = threading.Event()

    def on_timeout() -> None:
        timed_out.set()
        kill_process_group(proc.pid)

    timer = threading.Timer(timeout_s, on_timeout)
    timer.start()

    decoder = codecs.getincrementaldecoder("utf-8")(errors="replace")
    pending = ""
    lines: list[str] = []
    passed = False
    reason = ""

    try:
        assert proc.stdout is not None
        fd = proc.stdout.fileno()
        while True:
            chunk = os.read(fd, 4096)
            if not chunk:
                pending += decoder.decode(b"", final=True)
                if pending:
                    lines.append(pending.rstrip("\r"))
                    if verbose:
                        print(f"[{spec.target}] {lines[-1]}", flush=True)
                break

            pending += decoder.decode(chunk, final=False)
            while "\n" in pending:
                line, pending = pending.split("\n", 1)
                line = line.rstrip("\r")
                lines.append(line)
                if verbose:
                    print(f"[{spec.target}] {line}", flush=True)
                if any(m in line for m in spec.fail_markers):
                    reason = f"matched failure marker: {line}"
                    break
                if any(m in line for m in spec.pass_markers):
                    passed = True
                    reason = f"matched: {line}"
                    break

            if passed or reason:
                break

            # Match prompts without trailing newline (e.g. "buildroot login: ")
            if pending:
                if any(m in pending for m in spec.fail_markers):
                    lines.append(pending.rstrip("\r"))
                    reason = f"matched failure marker: {pending.strip()}"
                    break
                if any(m in pending for m in spec.pass_markers):
                    lines.append(pending.rstrip("\r"))
                    if verbose:
                        print(f"[{spec.target}] {lines[-1]}", flush=True)
                    passed = True
                    reason = f"matched: {pending.strip()}"
                    break

        if not passed and not reason:
            rc = proc.wait()
            reason = (
                f"timed out after {timeout_s}s"
                if timed_out.is_set()
                else f"exited early with code {rc} before pass marker"
            )
    finally:
        timer.cancel()
        kill_process_group(proc.pid)
        proc.wait()

    return SimResult(
        target=spec.target,
        passed=passed,
        duration_s=time.monotonic() - start,
        reason=reason,
        tail=lines[-30:],
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("filters", nargs="*", help="Substring filters on target names")
    parser.add_argument("--cores", type=int, default=6, help="nix build --cores")
    parser.add_argument("--max-jobs", type=int, default=1, help="nix build --max-jobs")
    parser.add_argument("-j", "--sim-jobs", type=int, default=6, help="Concurrent QEMU tests")
    parser.add_argument("-t", "--timeout", type=int, default=180, help="Per-test timeout (s)")
    parser.add_argument("--no-build", action="store_true", help="Use existing store paths only")
    parser.add_argument("-v", "--verbose", action="store_true", help="Stream QEMU output")
    args = parser.parse_args()

    selected = [
        s for s in SIM_SPECS if not args.filters or any(f in s.target for f in args.filters)
    ]
    if not selected:
        print(f"{RED}No simulation targets matched filters: {args.filters}{RESET}", file=sys.stderr)
        return 1

    print(f"{BOLD}{CYAN}🔨 Resolving {len(selected)} simulation target(s)...{RESET}")
    out_paths: dict[str, Path] = {}
    results: list[SimResult] = []
    for spec in selected:
        try:
            if args.no_build:
                raw = subprocess.check_output(
                    ["nix", "eval", "--raw", f"{spec.target}.outPath"],
                    cwd=ROOT,
                    text=True,
                ).strip()
                out_paths[spec.target] = Path(raw)
            else:
                print(f"  {DIM}▶ {spec.target}{RESET}")
                out_paths[spec.target] = build_target(spec.target, args.cores, args.max_jobs)
        except Exception as exc:
            err_lines = str(exc).splitlines()
            print(f"  {RED}❌ BUILD FAIL{RESET} {spec.target}")
            results.append(
                SimResult(
                    target=spec.target,
                    passed=False,
                    duration_s=0.0,
                    reason="nix build failed",
                    tail=err_lines[-30:],
                )
            )

    runnable = [s for s in selected if s.target in out_paths]
    if runnable:
        print(
            f"\n{BOLD}{CYAN}🧪 Running {len(runnable)} simulation test(s) "
            f"(jobs={args.sim_jobs}, timeout={args.timeout}s, empty PATH, cwd=/tmp)...{RESET}"
        )
        with ThreadPoolExecutor(max_workers=args.sim_jobs) as pool:
            futs = {
                pool.submit(run_sim, spec, out_paths[spec.target], args.timeout, args.verbose): spec
                for spec in runnable
            }
            for fut in as_completed(futs):
                res = fut.result()
                results.append(res)
                if res.passed:
                    print(
                        f"  {GREEN}✅ PASS{RESET} {res.target} {DIM}({res.duration_s:.1f}s){RESET}"
                    )
                else:
                    print(
                        f"  {RED}❌ FAIL{RESET} {res.target} {DIM}({res.duration_s:.1f}s){RESET}: "
                        f"{res.reason}"
                    )

    failed = [r for r in results if not r.passed]
    for res in failed:
        print(f"\n{BOLD}{RED}--- Failure tail: {res.target} ---{RESET}")
        for line in res.tail:
            print(f"  {line}")

    passed_count = len(results) - len(failed)
    print(
        f"\n{BOLD}Simulation Summary:{RESET} "
        f"{GREEN}{passed_count} passed{RESET}, {RED}{len(failed)} failed{RESET}"
    )
    return 0 if not failed else 1


if __name__ == "__main__":
    sys.exit(main())
