#!/usr/bin/env python3
"""Runs unchanged shared suites while MATLAB services file_adapter requests."""
import json
import os
from pathlib import Path
import signal
import subprocess
import sys


def atomic(path, value):
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(value), encoding="utf-8")
    os.replace(temporary, path)


active = None


def stop_active():
    global active
    if active is not None and active.poll() is None:
        try:
            os.killpg(active.pid, signal.SIGTERM)
        except ProcessLookupError:
            return
        try:
            active.wait(timeout=1)
        except subprocess.TimeoutExpired:
            os.killpg(active.pid, signal.SIGKILL)
            active.wait(timeout=1)


def run_child(command, timeout):
    global active
    active = subprocess.Popen(command, start_new_session=True)
    try:
        return active.wait(timeout=timeout)
    finally:
        stop_active()
        active = None


def terminate(signum, _frame):
    stop_active()
    raise SystemExit(128 + signum)


def main():
    global active
    signal.signal(signal.SIGTERM, terminate)
    signal.signal(signal.SIGINT, terminate)
    directory = Path(sys.argv[1])
    protocol = Path(sys.argv[2])
    os.chmod(directory, 0o700)
    os.environ["LICENSEBOX_MATLAB_IPC"] = str(directory)
    os.environ["PYTHONUNBUFFERED"] = "1"
    atomic(directory / "ready.json", {"ready": True})
    completed = 0
    result = 1
    try:
        adapter = Path(__file__).with_name("file_adapter.py")
        framing = run_child([sys.executable, str(Path(__file__).with_name("ipc_transport_test.py"))], 30)
        if framing:
            raise RuntimeError("negative IPC transport checks failed")
        for suite in ("run.py", "mex_strings.py", "heartbeat.py"):
            script = protocol / "conformance" / suite
            if not script.is_file():
                raise FileNotFoundError("shared conformance suite is missing: " + suite)
            command = [sys.executable, str(script), "--adapter", sys.executable, str(adapter)]
            returncode = run_child(command, 540)
            if returncode:
                result = returncode
                raise RuntimeError("shared suite failed: " + suite)
            completed += 1
        result = 0
    finally:
        atomic(directory / "finished.json", {"ok": result == 0, "suites": completed, "exit_code": result})
    return result


if __name__ == "__main__":
    raise SystemExit(main())
