#!/usr/bin/env python3
"""Test-only transport to an existing MATLAB kernel; no licensing substitution."""
import json
import os
from pathlib import Path
import sys
import time
import uuid


def main():
    directory = Path(os.environ["LICENSEBOX_MATLAB_IPC"])
    if not directory.is_dir() or directory.stat().st_mode & 0o077:
        raise RuntimeError("MATLAB adapter IPC directory must be private")
    request = sys.stdin.read()
    value = json.loads(request)
    if not isinstance(value, dict) or not isinstance(value.get("op"), str):
        raise ValueError("malformed adapter request")
    # Do not reserialize: escaped NUL and UTF-8 reach MATLAB's actual parser.
    prefix = directory / uuid.uuid4().hex
    staging = prefix.with_suffix(".tmp")
    pending = prefix.with_suffix(".request.json")
    response = prefix.with_suffix(".response.json")
    deadline = time.monotonic() + 12  # below shared runner's 15-second bound
    try:
        with staging.open("x", encoding="utf-8") as output:
            os.chmod(staging, 0o600)
            output.write(request)
        os.replace(staging, pending)
        while not response.exists():
            if (directory / "fatal").exists():
                raise RuntimeError("MATLAB adapter worker failed")
            if time.monotonic() >= deadline:
                raise TimeoutError("MATLAB adapter response deadline exceeded")
            time.sleep(0.01)
        answer = response.read_text(encoding="utf-8")
        parsed = json.loads(answer)
        if not isinstance(parsed, dict) or type(parsed.get("ok")) is not bool:
            raise ValueError("malformed MATLAB adapter response")
        if not parsed["ok"] and not isinstance(parsed.get("error"), str):
            raise ValueError("malformed MATLAB adapter error")
        print(answer.strip())
    finally:
        for path in (staging, pending, response):
            path.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
