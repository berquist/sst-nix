#!/usr/bin/env bash
# Build a flake package from the SST checkouts in this directory instead of
# the pinned upstream sources.  Uncommitted changes are included, because
# path: inputs copy the working tree.
#
# Usage: nix-build-local.sh [package, default sst-with-elements] [nix build args...]
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
pkg="${1:-sst-with-elements}"
shift || true

overrides=()
for input in sst-core sst-elements sst-macro sst-hgcc juno sst-external-element; do
    if [[ -e "${root}/${input}/.git" ]]; then
        overrides+=(--override-input "${input}" "path:${root}/${input}")
    fi
done

nix build "${root}#${pkg}" "${overrides[@]}" --no-write-lock-file \
    --out-link "${root}/result-${pkg}" "$@"
