# The packages of overlay.nix built with Clang instead of GCC.  Apply it
# after overlay.nix (flake.nix: overlays.clang does both).
#
# Only the packages that this flake compiles change; nixpkgs keeps its GCC
# builds, so that the rest still comes from the binary cache.  The compiler
# is the LLVM of sst-hgcc, with GCC's libstdc++ as in nixpkgs' clangStdenv.
#
# Not here: openmpi_4 (only the sqe modulefiles use it), intel-pin (a
# binary), gpgpu-sim (unfree, compiled by nvcc), lmod (Lua) and the vanadis
# cross compilers (they compile the guest programs).
final: prev:
let
  # Not final.lib: genAttrs below makes the attribute names of this overlay,
  # and final cannot be known before them.
  inherit (prev) lib;

  stdenv = final.sstClangStdenv;

  # sst-core, sst-dumpi, otf, PEBIL and epa-inst-libs compile with mpicc and
  # mpicxx, and the elements with the mpicxx that sst-config reports.  Open
  # MPI's wrappers call the GCC that Open MPI was built with unless these
  # name another compiler.
  mpiCompilerEnv = {
    OMPI_CC = "clang";
    OMPI_CXX = "clang++";
  };

  withClang =
    pkg:
    (pkg.override { inherit stdenv; }).overrideAttrs (old: {
      env = (old.env or { }) // mpiCompilerEnv;
    });
in
{
  sstClangStdenv = final.llvmPackages_22.stdenv;
  # For the dev shell (shells.nix).
  sstClangMpiCompilerEnv = mpiCompilerEnv;
}
// lib.genAttrs [
  "sst-core"
  "sst-elements"
  "sst-macro"
  "sst-hgcc"
  "juno"
  "sst-external-element"
  "sst-dumpi"
  "ramulator"
  "ramulator2"
  "goblin-hmcsim"
  "otf"
  "epa-inst-libs"
  "pebil"
] (name: withClang prev.${name})
