#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source ci/env.sh
matlab -batch "addpath('ci');build_and_test()"
