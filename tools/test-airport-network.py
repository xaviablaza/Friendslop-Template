#!/usr/bin/env python3
"""Reuse the foundation runner for actual airport co-op/host-loss checks."""
from pathlib import Path
import runpy

if __name__ == "__main__":
    foundation = runpy.run_path(str(Path(__file__).with_name("test-sushi-network.py")))
    foundation["OUTPUT"].mkdir(exist_ok=True)
    run_pair = foundation["run_pair"]
    run_pair("airport-network", 17117, lambda role: ["--", f"--airport-net-{role}"])
    run_pair("airport-host-loss", 17118, lambda role: [
        "--script", "res://test/integration/airport_host_loss.gd", "--", f"--airport-host-loss-{role}"
    ])
