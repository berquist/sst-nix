#!/usr/bin/env bash
# Run the test suites of the local builds (install/), as bamboo.sh does.
#
# Usage: test.sh <core|elements> [sst-test-* arguments...]
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
suite="${1:?usage: test.sh <core|elements> [arguments...]}"
shift
core="${root}/install/sst-core"
out="${root}/build/test-${suite}"

export PATH="${core}/bin:${PATH}"
mkdir --parents "${out}"
cd "${out}"
case "${suite}" in
core) sst-test-core "$@" ;;
elements) sst-test-elements "$@" ;;
*)
    echo "test.sh: unknown suite ${suite}" >&2
    exit 1
    ;;
esac
