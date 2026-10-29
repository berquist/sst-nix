# The musl cross compilers that rebuild the vanadis test programs of
# sst-elements (vanadis/tests/small/*/Makefile: CC=$(ARCH)-linux-musl-gcc,
# LDFLAGS=-static, ARCH riscv64 or mipsel).  Used when
# testsuite_default_vanadis.py has MakeTests = True.
#
# nixpkgs names the compilers by the full target triple
# (riscv64-unknown-linux-musl-gcc); this adds the names the Makefiles use.
{
  lib,
  path,
  stdenv,
  runCommand,
}:

let
  crossPkgs =
    config:
    import path {
      localSystem = stdenv.buildPlatform.system;
      crossSystem = { inherit config; };
    };
  targets = {
    riscv64 = crossPkgs "riscv64-unknown-linux-musl";
    mipsel = crossPkgs "mipsel-unknown-linux-musl";
  };
in
runCommand "vanadis-cross-compilers"
  {
    passthru = lib.mapAttrs (_: p: p.stdenv.cc) targets;
    meta.description = "musl cross compilers for the vanadis test programs";
  }
  (
    ''
      mkdir --parents $out/bin
    ''
    + lib.concatStrings (
      lib.mapAttrsToList (arch: p: ''
        for tool in gcc g++ cc c++ ld as ar strip objdump; do
          src=${p.stdenv.cc}/bin/${p.stdenv.cc.targetPrefix}$tool
          if [[ -e $src ]]; then
            ln --symbolic $src $out/bin/${arch}-linux-musl-$tool
          fi
        done
      '') targets
    )
  )
