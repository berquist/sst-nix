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
# The patches of the Nix packages (nix/patches/<project>) go into the
# checkout before the build, so that local and Nix builds compile the same
# source.  A patch that is already applied is skipped.  Unlike the Nix
# packages, every patch is applied, whatever the dependencies.
#
# The clang shell sets SST_TOOLCHAIN=clang; its builds go to build-clang/ and
# install-clang/ instead.
#
# Usage: build.sh <project> [extra configure arguments...]
#   project: sst-core, sst-elements, sst-macro, sst-hgcc, juno,
#            sst-external-element
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project="${1:?usage: build.sh <project> [configure arguments...]}"
shift
toolchain="${SST_TOOLCHAIN:-gcc}"
suffix=""
if [[ "${toolchain}" != gcc ]]; then
    suffix="-${toolchain}"
fi
src="${root}/${project}"
build="${root}/build${suffix}/${project}"
install="${root}/install${suffix}"
prefix="${install}/${project}"
core="${install}/sst-core"
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

# Apply nix/patches/<name>/*.patch to a directory, unless already applied:
# then the reverse applies cleanly.  --force stops patch from taking an
# unapplied patch for a reversed one.  Sets `patched` when a patch goes in.
patched=0
apply_patches() {
    local dir="$1" name="$2" file
    for file in "${root}/nix/patches/${name}"/*.patch; do
        if patch --directory="${dir}" --strip=1 --reverse --force --dry-run \
            <"${file}" >/dev/null 2>&1; then
            echo "build.sh: ${name}/${file##*/} is already applied"
        else
            echo "build.sh: applying ${name}/${file##*/}"
            patch --directory="${dir}" --strip=1 --forward <"${file}"
            patched=1
        fi
    done
}

# A build tree from before a patch can be stale: make does not relink a
# library when only its link flags change.  Start that tree again.
clean_if_patched() {
    if [[ "${patched}" -eq 1 ]]; then
        echo "build.sh: new patches; removing ${build}"
        rm --recursive --force "${build}"
    fi
}

autotools() {
    local generate="$1"
    shift
    (cd "${src}" && "${generate}")
    configure_and_install "$@"
}

configure_and_install() {
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
    apply_patches "${src}" sst-elements
    clean_if_patched
    read -ra flags <<<"${SST_ELEMENTS_CONFIGURE_FLAGS:-}"
    autotools ./autogen.sh --with-sst-core="${core}" "${flags[@]}" "$@"
    ;;
sst-macro)
    need_core
    apply_patches "${src}" sst-macro
    # bootstrap.sh runs `git submodule update`, so the sst-dumpi patches go
    # in after it.  None of them changes the build system.
    (cd "${src}" && ./bootstrap.sh)
    apply_patches "${src}/sst-dumpi" sst-dumpi
    clean_if_patched
    configure_and_install --with-sst-core="${core}" \
        --disable-regex --disable-unordered-containers "$@"
    ;;
sst-hgcc)
    need_core
    autotools ./autogen.sh --with-sst-core="${core}" \
        --with-sst-elements="${install}/sst-elements" \
        --with-clang="${LLVM_ROOT:?LLVM_ROOT is not set; use the dev shell}" \
        --with-std=17 --enable-strict-tests "$@"
    ;;
juno)
    # The Makefiles build in the checkout; `install` runs sst-register
    # with the checkout paths.  --always-make, because the objects in the
    # checkout can be from the other toolchain.
    need_core
    make --directory="${src}/src" --jobs="${jobs}" --always-make
    make --directory="${src}/asm" --always-make CXX=c++ sst-juno-asm
    ;;
sst-external-element)
    need_core
    make --directory="${src}/src" --always-make
    ;;
*)
    echo "build.sh: unknown project ${project}" >&2
    exit 1
    ;;
esac
