#!/usr/bin/env python3
"""Run two real ENet peers; optionally record both actual windows together.

Warm-up collects naturally arriving baggage with normal player inputs. Only the
recording start cue is file-driven; bag positions, velocities and catch outcomes
come from the authoritative game, not fixtures or reconstructed animation.
"""
import argparse
import json
import os
from pathlib import Path
import re
import select
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "artifacts"
ENGINE = os.environ.get("GODOT", "godot")
CAPTURE = OUT / "airport-bag-throws-vertical-capture.mp4"
VIDEO = OUT / "airport-bag-throws-vertical.mp4"
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"


def vertical_filter(time_scale):
    """Stack complete 4:3 views; all headings occupy added canvas, not game pixels."""
    def text(value, y, size, color="white"):
        return (f"drawtext=fontfile={FONT}:text='{value}':fontsize={size}:"
                f"fontcolor={color}:x=(w-text_w)/2:y={y}")
    captions = [
        text("AIRPORT BAGGAGE", 24, 44, "0xe2c77d"),
        text("Weighted Throws & Mid-Air Catches", 80, 30),
        text("8 / 16 / 28 kg  |  AUTOMATED TWO-PLAYER PLAYTEST", 126, 19, "0xacbdcc"),
        text("PLAYER 1", 170, 26, "0xe2c77d"),
        text("PLAYER 2", 1050, 26, "0x80c8e2"),
    ]
    return (
        f"[0:v]setpts={time_scale}*PTS,fps=24,split=2[a][b];"
        "[a]crop=640:480:0:0,scale=1080:810,setsar=1,"
        "pad=1080:1018:0:208:color=0x101c27[p1];"
        "[b]crop=640:480:640:0,scale=1080:810,setsar=1,"
        "pad=1080:902:0:92:color=0x101c27[p2];"
        "[p1][p2]vstack=inputs=2," + ",".join(captions) + "[video]"
    )


def stop(process):
    if process and process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()


def validate(quick=False):
    reports = {}
    for role in ("host", "client"):
        report = json.loads((OUT / f"throw-{role}.json").read_text())
        assert report["passed"] and report["real_enet_peers"], report
        diagnostics = [line for line in (OUT / f"throw-{role}.log").read_text().splitlines()
                       if "ERROR:" in line or "SCRIPT ERROR:" in line]
        assert not diagnostics, {"role": role, "diagnostics": diagnostics}
        reports[role] = report
    host = reports["host"]
    assert host["peer_id"] == 1 and reports["client"]["peer_id"] != 1
    peer_ids = {host["peer_id"], reports["client"]["peer_id"]}
    required = 2 if quick else 6
    assert host["catches"] >= required and reports["client"]["catches"] >= required
    assert {event["peer_id"] for event in host["catch_events"]} == peer_ids
    assert all(event["height"] > 0.12 for event in host["catch_events"])
    for peer in peer_ids:
        assert {event["mass_kg"] for event in host["catch_events"] if event["peer_id"] == peer} == ({8.0} if quick else {8.0, 16.0, 28.0})
    measurements = host["range_measurements"]
    assert [item["mass_kg"] for item in measurements] == ([8.0] if quick else [8.0, 16.0, 28.0])
    if not quick:
        assert measurements[0]["ground_range"] > measurements[1]["ground_range"] > measurements[2]["ground_range"]
    print(json.dumps({
        "passed": True,
        "host_checks": len(host["checks"]),
        "client_checks": len(reports["client"]["checks"]),
        "peer_ids": sorted(peer_ids),
        "catch_events": host["catch_events"],
        "weighted_ground_throws": measurements,
    }, indent=2))
    return reports


def run(record=False, quick=False, time_scale=1.0):
    OUT.mkdir(exist_ok=True)
    (OUT / ".gdignore").touch()
    cue = OUT / "throw-start.flag"
    cue.unlink(missing_ok=True)
    for role in ("host", "client"):
        (OUT / f"throw-{role}.json").unlink(missing_ok=True)
    env = os.environ.copy()
    processes = []
    logs = []
    xvfb = None
    recorder = None
    try:
        if record:
            read_fd, write_fd = os.pipe()
            display_log = (OUT / "throw-xvfb.log").open("w")
            logs.append(display_log)
            xvfb = subprocess.Popen(
                ["Xvfb", "-displayfd", str(write_fd), "-screen", "0", "1280x480x24", "-nolisten", "tcp"],
                pass_fds=(write_fd,), stdout=display_log, stderr=subprocess.STDOUT,
            )
            os.close(write_fd)
            try:
                if not select.select([read_fd], [], [], 15)[0]:
                    raise TimeoutError("Private Xvfb display did not become ready")
                display = os.read(read_fd, 128).decode().strip()
            finally:
                os.close(read_fd)
            assert display.isdigit(), display
            env.update(DISPLAY=f":{display}", LIBGL_ALWAYS_SOFTWARE="1", LP_NUM_THREADS="6")
        for index, role in enumerate(("host", "client")):
            log = (OUT / f"throw-{role}.log").open("w")
            logs.append(log)
            command = [ENGINE, "--path", str(ROOT), "--time-scale", str(time_scale)]
            if record:
                command += ["--windowed", "--resolution", "640x480", "--position", f"{index * 640},0",
                            "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy",
                            "--disable-vsync", "--max-fps", "30"]
            else:
                command += ["--headless", "--max-fps", "120"]
            command += ["--", f"--airport-throw-{role}"]
            if quick:
                command += ["--airport-throw-quick"]
            process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
            processes.append((role, process))
            if role == "host":
                started = time.monotonic()
                while True:
                    if process.poll() is not None:
                        raise RuntimeError("Host exited before binding throwing-test port")
                    sockets = Path("/proc/net/udp").read_text() + Path("/proc/net/udp6").read_text()
                    if f":{17127:04X} " in sockets:
                        break
                    if time.monotonic() - started > 15:
                        raise TimeoutError("Host never bound 17127/UDP")
                    time.sleep(0.1)
        started = time.monotonic()
        while "THROW_CAPTURE_READY" not in (OUT / "throw-host.log").read_text():
            if any(process.poll() is not None for _, process in processes):
                raise RuntimeError("A peer exited during input-driven warm-up; inspect throw logs")
            if time.monotonic() - started > 120 / time_scale:
                raise TimeoutError("Players did not finish collecting natural arrivals")
            time.sleep(0.1)
        if record:
            subprocess.run([
                "ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-f", "x11grab", "-draw_mouse", "0",
                "-video_size", "1280x480", "-i", env["DISPLAY"], "-frames:v", "1", str(OUT / "throw-dual-ready.png")
            ], check=True)
            recorder_log = (OUT / "throw-recorder.log").open("w")
            logs.append(recorder_log)
            recorder = subprocess.Popen([
                "ffmpeg", "-hide_banner", "-loglevel", "warning", "-y", "-f", "x11grab", "-draw_mouse", "0",
                "-framerate", "24", "-video_size", "1280x480", "-i", env["DISPLAY"], "-an",
                "-c:v", "libx264", "-preset", "veryfast", "-threads", "4", "-crf", "20", "-pix_fmt", "yuv420p",
                "-movflags", "+faststart", "-progress", "pipe:1", "-nostats", str(CAPTURE)
            ], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=recorder_log)
            assert recorder.stdout is not None and recorder.stdin is not None
            progress = b""
            deadline = time.monotonic() + 12
            while not re.search(rb"frame=\s*[1-9]", progress):
                if recorder.poll() is not None or time.monotonic() > deadline:
                    raise RuntimeError("Desktop recorder failed to capture actual frames")
                if select.select([recorder.stdout], [], [], 0.5)[0]:
                    progress += os.read(recorder.stdout.fileno(), 4096)
        cue.touch()
        print("Actual two-peer throw/catch sequence started", flush=True)
        while any(process.poll() is None for _, process in processes):
            for role, process in processes:
                if process.poll() not in (None, 0):
                    raise RuntimeError(f"{role} failed: inspect artifacts/throw-{role}.log")
            if time.monotonic() - started > 230 / time_scale:
                raise TimeoutError("Throw/catch session exceeded its bounded duration")
            # Drain ffmpeg progress so the recorder cannot block on its output pipe.
            if recorder:
                assert recorder.stdout is not None
                if select.select([recorder.stdout], [], [], 0)[0]:
                    os.read(recorder.stdout.fileno(), 8192)
            time.sleep(0.1)
        if recorder:
            assert recorder.stdin is not None
            recorder.stdin.write(b"q\n")
            recorder.stdin.flush()
            if recorder.wait(timeout=30):
                raise RuntimeError("Recorder failed to finalize MP4")
        reports = validate(quick)
        if record:
            # Preserve both full native views; compose on external title-bar canvas.
            subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(CAPTURE),
                            "-filter_complex", vertical_filter(time_scale), "-map", "[video]", "-an",
                            "-c:v", "libx264", "-preset", "veryfast", "-threads", "4", "-crf", "21",
                            "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(VIDEO)], check=True)
            subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-i", str(VIDEO), "-f", "null", "-"], check=True)
            probe = json.loads(subprocess.check_output([
                "ffprobe", "-v", "error", "-show_entries",
                "format=duration,size:stream=codec_name,width,height,r_frame_rate", "-of", "json", str(VIDEO)
            ], text=True))
            stream = probe["streams"][0]
            assert (stream["width"], stream["height"]) == (1080, 1920), probe
            print(json.dumps(probe, indent=2))
            print(f"Verified vertical two-player recording: {VIDEO}")
        return reports
    finally:
        stop(recorder)
        for _, process in processes:
            stop(process)
        stop(xvfb)
        for log in logs:
            log.close()
        cue.unlink(missing_ok=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--record", action="store_true", help="Record both actual game windows on a private display")
    parser.add_argument("--quick", action="store_true", help="Focused light-bag network regression (not full acceptance)")
    parser.add_argument("--time-scale", type=float, default=1.0, choices=[0.25, 0.5, 1.0],
                        help="Slower simulation for CPU rendering; final video is normalized to normal speed")
    args = parser.parse_args()
    run(args.record, args.quick, args.time_scale)
