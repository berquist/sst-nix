#!/usr/bin/env bash
# Run the test suites of the local builds (install/), as bamboo.sh does.
# In the clang shell (SST_TOOLCHAIN=clang), those of install-clang/.
#
# Usage: test.sh <core|elements> [sst-test-* arguments...]
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
suite="${1:?usage: test.sh <core|elements> [arguments...]}"
shift
toolchain="${SST_TOOLCHAIN:-gcc}"
suffix=""
if [[ "${toolchain}" != gcc ]]; then
    suffix="-${toolchain}"
fi
core="${root}/install${suffix}/sst-core"
out="${root}/build${suffix}/test-${suite}"

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
