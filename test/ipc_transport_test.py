#!/usr/bin/env python3
"""Negative framing tests only; real successful licensing is tested by MATLAB."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time

ADAPTER = Path(__file__).with_name("file_adapter.py")


def execute(directory, text):
    environment = dict(os.environ, LICENSEBOX_MATLAB_IPC=str(directory))
    result = subprocess.run([sys.executable, str(ADAPTER)], input=text,
                            text=True, capture_output=True, env=environment, timeout=14)
    assert result.returncode != 0, "malformed/failed transport was accepted"


def main():
    with tempfile.TemporaryDirectory(prefix="licensebox-matlab-transport-") as location:
        directory = Path(location)
        for malformed in ("not JSON", "[]", '{"op":1}', "{}"):
            execute(directory, malformed)
            assert not list(directory.iterdir()), "malformed input left IPC state"
        (directory / "fatal").write_text("expected transport failure", encoding="utf-8")
        execute(directory, '{"op":"native","product":"demo"}')
        (directory / "fatal").unlink()
        assert not list(directory.iterdir()), "fatal worker left IPC requests"
        # Deliberately malformed response: this does not imitate authorization.
        environment = dict(os.environ, LICENSEBOX_MATLAB_IPC=str(directory))
        child = subprocess.Popen([sys.executable, str(ADAPTER)], stdin=subprocess.PIPE,
                                 stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                 text=True, env=environment)
        try:
            child.stdin.write('{"op":"native","product":"demo"}')
            child.stdin.close()
            deadline = time.monotonic() + 3
            while not list(directory.glob("*.request.json")):
                assert time.monotonic() < deadline, "transport did not submit request"
                time.sleep(.01)
            request = next(directory.glob("*.request.json"))
            response = request.with_name(request.name.replace(".request.json", ".response.json"))
            response.write_text("[]", encoding="utf-8")
            assert child.wait(timeout=3) != 0, "malformed response was accepted"
        finally:
            if child.poll() is None:
                child.kill()
                child.wait(timeout=3)
        assert not list(directory.iterdir()), "malformed response left IPC state"
        started = time.monotonic()
        execute(directory, json.dumps({"op": "native", "product": "demo"}))
        assert time.monotonic() - started < 14, "transport did not enforce response deadline"
        assert not list(directory.iterdir()), "timeout left IPC state"
    print("PASS: MATLAB IPC malformed input/response, worker failure, deadline and cleanup", flush=True)


if __name__ == "__main__":
    main()
