# Ramulator: cycle-accurate DRAM simulator, used by the ramulator backend of
# SST memHierarchy.  Not in nixpkgs.
#
# The commit and the patches are those of sst-sqe
# (buildsys/deps/bin/sstDep_ramulator_stabledevel.sh, buildsys/deps/patches).
# Upstream has no install target.  configure of sst-elements wants the
# headers in DIR/src and the library in DIR, so passthru.sstPrefix is such a
# tree of links into the normal layout.
{
  lib,
  stdenv,
  fetchFromGitHub,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "ramulator";
  version = "0-unstable-2018-01-25";

  src = fetchFromGitHub {
    owner = "CMU-SAFARI";
    repo = "ramulator";
    rev = "7d2e72306c6079768e11a1867eb67b60cee34a1c";
    hash = "sha256-pFbhhTSzvpphLPrxQ9zaYBOGOzokAbN+oNAEiob++aY=";
  };

  patches = [
    # Explicit std::bind in place of lambdas in member initialisers.
    ./patches/ramulator/ramulator_gcc48Patch.patch
    ./patches/ramulator/ramulator_include.patch
    # -fpic and a libramulator.so target.
    ./patches/ramulator/ramulator_libPatch.patch
  ];

  makeFlags = [ "CXX=${stdenv.cc.targetPrefix}c++" ];

  buildFlags = [
    "ramulator"
    "libramulator${stdenv.hostPlatform.extensions.sharedLibrary}"
  ];

  enableParallelBuilding = true;

  installPhase = ''
    runHook preInstall
    install -D --mode=755 ramulator $out/bin/ramulator
    install -D --mode=755 libramulator${stdenv.hostPlatform.extensions.sharedLibrary} --target-directory=$out/lib
    install -D --mode=644 src/*.h --target-directory=$out/include/ramulator
    mkdir --parents $out/share/ramulator $out/share/ramulator/sst
    cp --recursive configs $out/share/ramulator/
    ln --symbolic $out/include/ramulator $out/share/ramulator/sst/src
    ln --symbolic $out/lib/libramulator${stdenv.hostPlatform.extensions.sharedLibrary} $out/share/ramulator/sst/
    runHook postInstall
  '';

  # Two DRAM standards on the example DRAM trace of the repository.  The CPU
  # trace mode runs for a long time.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    $out/bin/ramulator configs/DDR3-config.cfg --mode=dram dram.trace
    $out/bin/ramulator configs/DDR4-config.cfg --mode=dram dram.trace
    test -s DDR3.stats
    test -s DDR4.stats
    runHook postInstallCheck
  '';

  passthru.sstPrefix = "${finalAttrs.finalPackage}/share/ramulator/sst";

  meta = {
    description = "Fast and cycle-accurate DRAM simulator";
    homepage = "https://github.com/CMU-SAFARI/ramulator";
    license = lib.licenses.mit;
    mainProgram = "ramulator";
    platforms = lib.platforms.unix;
  };
})
