#!/usr/bin/env bash
set -euo pipefail
command -v matlab >/dev/null || { echo 'MATLAB with a licensed runtime is required. Install using matlab-actions/setup-matlab.' >&2; exit 1; }
