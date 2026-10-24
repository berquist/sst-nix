#!/usr/bin/env bash
# Configure, build and install one of the SST checkouts in this directory,
# out of source, against the other local builds.  Run it in the dev shell.
#
#   build/<project>    build tree
#   install/<project>  prefix
#
# sst-elements gets $SST_ELEMENTS_CONFIGURE_FLAGS from the dev shell: every
# optional dependency the shell provides.  Element libraries register with
# install/sst-core/etc/sst/sstsimulator.conf.
#
# Usage: build.sh <project> [extra configure arguments...]
#   project: sst-core, sst-elements, sst-macro, sst-hgcc, juno,
#            sst-external-element
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project="${1:?usage: build.sh <project> [configure arguments...]}"
shift
src="${root}/${project}"
build="${root}/build/${project}"
prefix="${root}/install/${project}"
core="${root}/install/sst-core"
jobs="$(nproc)"

if [[ ! -d "${src}" ]]; then
    echo "build.sh: no checkout at ${src}" >&2
    exit 1
fi

need_core() {
    if [[ ! -x "${core}/bin/sst-config" ]]; then
        echo "build.sh: build sst-core first (just build sst-core)" >&2
        exit 1
    fi
    export PATH="${core}/bin:${PATH}"
}

autotools() {
    local generate="$1"
    shift
    (cd "${src}" && "${generate}")
    mkdir --parents "${build}"
    cd "${build}"
    "${src}/configure" --prefix="${prefix}" "$@"
    make --jobs="${jobs}"
    make install
}

case "${project}" in
sst-core)
    autotools ./autogen.sh "$@"
    ;;
sst-elements)
    need_core
    read -ra flags <<<"${SST_ELEMENTS_CONFIGURE_FLAGS:-}"
    autotools ./autogen.sh --with-sst-core="${core}" "${flags[@]}" "$@"
    ;;
sst-macro)
    need_core
    autotools ./bootstrap.sh --with-sst-core="${core}" \
        --disable-regex --disable-unordered-containers "$@"
    ;;
sst-hgcc)
    need_core
    autotools ./autogen.sh --with-sst-core="${core}" \
        --with-sst-elements="${root}/install/sst-elements" \
        --with-clang="${LLVM_ROOT:?LLVM_ROOT is not set; use the dev shell}" \
        --with-std=17 --enable-strict-tests "$@"
    ;;
juno)
    # The Makefiles build in the checkout; `install` runs sst-register
    # with the checkout paths.
    need_core
    make --directory="${src}/src" --jobs="${jobs}"
    make --directory="${src}/asm" CXX=c++ sst-juno-asm
    ;;
sst-external-element)
    need_core
    make --directory="${src}/src"
    ;;
*)
    echo "build.sh: unknown project ${project}" >&2
    exit 1
    ;;
esac
