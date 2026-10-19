#!/usr/bin/env python3
"""Reuse the user's throw runner without changing its legacy 28 kg/video WIP.

Expansion co-op forbids throws above the 24 kg shared-carry threshold, so the
full ordinary-key relay uses explicit additive 8/16/23 kg fixtures. No video.
"""
import json
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "artifacts"


def validate_expansion(quick=False):
    reports = {}
    expected = {8.0} if quick else {8.0, 16.0, 23.0}
    for role in ("host", "client"):
        report = json.loads((OUT / f"throw-{role}.json").read_text())
        assert report["passed"] and report["real_enet_peers"], report
        assert report["quick_regression"] == quick, report
        assert report["simulation_time_scale"] == 1.0, report
        errors = [line for line in (OUT / f"throw-{role}.log").read_text().splitlines()
                  if "ERROR:" in line or "SCRIPT ERROR:" in line]
        assert not errors, {"role": role, "errors": errors}
        reports[role] = report
    host, client = reports["host"], reports["client"]
    assert host["peer_id"] == 1 and client["peer_id"] != 1
    peers = {host["peer_id"], client["peer_id"]}
    for report in reports.values():
        events = report["catch_events"]
        assert report["catches"] >= (2 if quick else 6)
        assert {event["peer_id"] for event in events} == peers
        assert all(event["height"] > 0.12 and event["flight_age"] >= 0.08 for event in events)
        for peer in peers:
            assert {event["mass_kg"] for event in events if event["peer_id"] == peer} == expected
    measurements = host["range_measurements"]
    assert [item["mass_kg"] for item in measurements] == sorted(expected)
    if not quick:
        assert measurements[0]["ground_range"] > measurements[1]["ground_range"] > measurements[2]["ground_range"]
    print(json.dumps({"passed": True, "host_checks": len(host["checks"]),
                      "client_checks": len(client["checks"]), "weights_kg": sorted(expected),
                      "catch_events": host["catch_events"], "ranges": measurements}, indent=2))
    return reports


if __name__ == "__main__":
    runner = runpy.run_path(str(Path(__file__).with_name("test-airport-throws.py")))
    # Reuse launch/cue/cleanup; only replace validation's obsolete weight set.
    runner["run"].__globals__["validate"] = validate_expansion
    runner["run"](record=False, quick=False, time_scale=1.0)
