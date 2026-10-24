# Goblin HMC-Sim: Hybrid Memory Cube simulator, used by the goblinHMCSim
# backend of SST memHierarchy.  Not in nixpkgs.
#
# The branch is the one of sst-sqe
# (buildsys/deps/bin/sstDep_goblin_hmcsim_stabledevel.sh).
{
  lib,
  stdenv,
  fetchFromGitHub,
}:

stdenv.mkDerivation {
  pname = "goblin-hmcsim";
  version = "3.0-unstable-2018-02-13";

  # Branch sst-8.0.0-release
  src = fetchFromGitHub {
    owner = "tactcomplabs";
    repo = "gc64-hmcsim";
    rev = "6a066f51af9ecde879502237f63b33da21d3208a";
    hash = "sha256-MiwL3vNXChtqhbVXZcW1gCHSRYK4YmEJI9H8EbMKiWw=";
  };

  # The Makefiles set CC=gcc and an absolute PREFIX in Makefile.inc.
  makeFlags = [
    "CC=${stdenv.cc.targetPrefix}cc"
    "CXX=${stdenv.cc.targetPrefix}c++"
    "AR=${stdenv.cc.targetPrefix}ar"
    "PREFIX=${placeholder "out"}"
  ];

  # The test programs, and the CMC libraries that `make install` copies.
  buildFlags = [
    "all"
    "cmc"
    "test"
  ];

  # Each Makefile level calls `make` on the next one with no -j.
  enableParallelBuilding = false;

  # The library and the CMC plugins, with the device of the stream scripts
  # (test/stream/scripts/4link_2GB_stream.sh) and fewer requests.  This
  # version wants 8 vaults per link and at least 4 GB, so 32 vaults and 4 GB
  # in place of the 16 and 2 there.  sst_init uses the SST defaults.
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    export LD_LIBRARY_PATH="$PWD''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    hmc="-b 8 -c 4 -l 4 -n 1 -q 64 -x 128 -d 20 -v 32"
    (cd test/sst_init && ./sst_init)
    (cd test/simple && ./simple $hmc)
    (cd test/simple_cmc && ./simple_cmc $hmc)
    (cd test/stream && ./stream $hmc -m 64 -N 4096 -T 16 -s 8)
    runHook postCheck
  '';

  meta = {
    description = "Hybrid Memory Cube functional and cycle-based simulator";
    homepage = "https://github.com/tactcomplabs/gc64-hmcsim";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.unix;
  };
}
