#!/usr/bin/env bash
# Run sst-sqe/dev/run-bamboo-like-github.sh unchanged, with its output in a
# log file as its header asks.  It needs the dev shell (Lmod, the
# mpi/openmpi-4.1.4 module) and network access, because bamboo.sh clones
# the SST repositories from GitHub.
#
# Usage: sqe.sh [log file, default bamboo-<date>.log]
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
log="${1:-${root}/bamboo-$(date +%Y-%m-%d-%H%M%S).log}"

if ! declare -F module >/dev/null; then
    echo "sqe.sh: no module function; run in the dev shell" >&2
    exit 1
fi

echo "sqe.sh: writing ${log}"
cd "${root}/sst-sqe"
./dev/run-bamboo-like-github.sh >"${log}" 2>&1
