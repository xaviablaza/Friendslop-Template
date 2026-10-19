#!/usr/bin/env python3
"""Exercise real ENet processes for gameplay and graceful host loss."""
import json
import os
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "artifacts"
ENGINE = os.environ.get("GODOT", "godot")


def run_pair(prefix, port, arguments):
    for role in ("host", "client"):
        (OUTPUT / f"{prefix}-{role}.json").unlink(missing_ok=True)
    processes = []
    try:
        for role in ("host", "client"):
            log_path = OUTPUT / f"{prefix}-{role}.log"
            log = log_path.open("w")
            process = subprocess.Popen(
                [ENGINE, "--headless", "--path", str(ROOT), *arguments(role)],
                cwd=ROOT, stdout=log, stderr=subprocess.STDOUT,
            )
            processes.append((role, process, log, log_path))
            if role == "host":
                started = time.monotonic()
                while True:
                    if process.poll() is not None:
                        raise RuntimeError(f"{prefix} host exited before opening its lobby")
                    sockets = Path("/proc/net/udp").read_text() + Path("/proc/net/udp6").read_text()
                    if f":{port:04X} " in sockets:
                        break
                    if time.monotonic() - started > 15:
                        raise TimeoutError(f"Host never bound test port {port}")
                    time.sleep(0.1)
        for role, process, log, log_path in processes:
            code = process.wait(timeout=75)
            log.close()
            report_file = OUTPUT / f"{prefix}-{role}.json"
            if code or not report_file.exists():
                raise RuntimeError(f"{prefix}/{role} exited {code}: see {log_path}")
            report = json.loads(report_file.read_text())
            assert report["passed"], report
            diagnostics = [line for line in log_path.read_text().splitlines()
                           if "ERROR:" in line or "SCRIPT ERROR:" in line]
            assert not diagnostics, {"log": str(log_path), "errors": diagnostics}
            print(json.dumps(report, indent=2))
        print(f"PASS: {prefix} on two actual ENet processes; no runtime errors")
    finally:
        for _role, process, log, _log_path in processes:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
            log.close()


def main():
    OUTPUT.mkdir(exist_ok=True)
    run_pair("network", 17107, lambda role: ["--", f"--sushi-net-{role}"])
    run_pair("host-loss", 17108, lambda role: [
        "--script", "res://test/integration/sushi_host_loss.gd", "--", f"--host-loss-{role}"
    ])


if __name__ == "__main__":
    main()
