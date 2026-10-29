# The riscv64 GNU (glibc) toolchain of the balar tests.  They build their
# Vanadis programs (balar/tests/libcudart, balar/tests/vanadis_llvm_rv64)
# with it and with Clang, through RISCV_TOOLCHAIN_INSTALL_PATH.  The
# Makefiles expect the install layout of riscv-gnu-toolchain
# (balar/README.md):
#
#   bin/riscv64-unknown-linux-gnu-gcc  and the other tools
#   sysroot/usr/include                glibc and Linux headers
#   riscv64-unknown-linux-gnu/include/c++/<version>
#                                      libstdc++ headers
#
# Clang, given --gcc-toolchain and --sysroot, also looks for:
#
#   lib/gcc/riscv64-unknown-linux-gnu/<version>
#                                      crtbegin.o, libgcc.a
#   riscv64-unknown-linux-gnu/bin      ld and as
#   riscv64-unknown-linux-gnu/lib      libstdc++.a
#   sysroot/usr/lib                    crt1.o, libc.a and the other static
#                                      glibc libraries (the programs are
#                                      linked with -static)
#
# This puts the parts of the nixpkgs riscv64 cross toolchain in that layout.
# The directories are copies with symlinked files, not symlinks: Clang
# finds some of them with paths such as <gcc dir>/../../../../<triple>/lib,
# and `..` after a symlink leaves the layout.
{
  lib,
  path,
  stdenv,
  runCommand,
}:

let
  crossPkgs = import path {
    localSystem = stdenv.buildPlatform.system;
    crossSystem.config = "riscv64-unknown-linux-gnu";
  };
  inherit (crossPkgs) linuxHeaders;
  cc = crossPkgs.stdenv.cc;
  gcc = cc.cc;
  glibc = cc.libc;
  binutils = cc.bintools.bintools;
  triple = crossPkgs.stdenv.hostPlatform.config;
in
runCommand "balar-riscv-toolchain"
  {
    passthru = { inherit cc; };
    meta.description = "riscv64 glibc toolchain in the riscv-gnu-toolchain layout, for the balar tests";
  }
  ''
    # Merge directories as copies with symlinked files.  --force, because
    # the outputs of one package can have the same file.
    merge() {
      mkdir --parents "$2"
      cp --recursive --symbolic-link --force "$1"/. "$2"/
      chmod --recursive u+w "$2"
    }

    # The compilers and binutils, with the target prefix.
    mkdir --parents $out/bin
    for tool in ${cc}/bin/${triple}-* ${cc.bintools}/bin/${triple}-*; do
      ln --symbolic --force "$tool" $out/bin/
    done

    # Unprefixed ld and as, where Clang looks for them.
    mkdir --parents $out/${triple}/bin
    for tool in ld ld.bfd as ar ranlib nm objcopy objdump strip; do
      if [[ -e ${binutils}/bin/${triple}-$tool ]]; then
        ln --symbolic ${binutils}/bin/${triple}-$tool $out/${triple}/bin/$tool
      fi
    done

    # The GCC version is the name of the directory of crtbegin.o.
    crtbegin=$(find ${gcc} ${lib.getLib gcc} -path '*/lib/gcc/${triple}/*/crtbegin.o' -print -quit)
    if [[ -z $crtbegin ]]; then
      echo "balar-riscv-toolchain: no crtbegin.o for ${triple} in ${gcc}" >&2
      exit 1
    fi
    version=$(basename "$(dirname "$crtbegin")")

    for output in ${gcc} ${lib.getLib gcc}; do
      if [[ -d $output/lib/gcc/${triple}/$version ]]; then
        merge $output/lib/gcc/${triple}/$version $out/lib/gcc/${triple}/$version
      fi
    done

    # libstdc++: the headers, and the libraries next to the target lib.
    cxxheader=$(find ${gcc} -path "*/include/c++/$version/iostream" -print -quit)
    if [[ -z $cxxheader ]]; then
      echo "balar-riscv-toolchain: no libstdc++ headers for $version in ${gcc}" >&2
      exit 1
    fi
    merge "$(dirname "$cxxheader")" $out/${triple}/include/c++/$version

    libstdcxx=$(find ${gcc} ${lib.getLib gcc} -name 'libstdc++.a' -print -quit)
    if [[ -z $libstdcxx ]]; then
      echo "balar-riscv-toolchain: no libstdc++.a in ${gcc}" >&2
      exit 1
    fi
    merge "$(dirname "$libstdcxx")" $out/${triple}/lib

    # The sysroot: glibc and Linux headers, and the glibc libraries with
    # the static ones.
    merge ${lib.getDev glibc}/include $out/sysroot/usr/include
    merge ${linuxHeaders}/include $out/sysroot/usr/include
    merge ${lib.getLib glibc}/lib $out/sysroot/usr/lib
    merge ${glibc.static}/lib $out/sysroot/usr/lib
  ''
