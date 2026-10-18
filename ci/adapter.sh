#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source ci/env.sh
request_file=$(mktemp)
trap 'rm -f "$request_file"' EXIT
cat > "$request_file"
export LICENSEBOX_CONFORMANCE_INPUT="$request_file"
matlab -batch "addpath('src');addpath('build');addpath('test');adapter()"
