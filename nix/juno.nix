# Juno: small processor model with its own assembler, an example SST element
# outside sst-elements.  Not in nixpkgs.
#
# The Makefile `install` target registers the build directory with
# sst-register; this package installs the library and writes the
# sstsimulator.conf fragment itself (see sst-elements.nix).  The test suite
# finds the assembler and the programs relative to its own directory, so
# share/juno keeps the layout of the repository.
{
  lib,
  stdenv,
  src,
  version,
  sst-core,
}:

stdenv.mkDerivation {
  pname = "juno";
  inherit src version;

  nativeBuildInputs = [ sst-core ];

  buildPhase = ''
    runHook preBuild
    make -C src ''${enableParallelBuilding:+-j$NIX_BUILD_CORES} libjuno.so
    make -C asm ''${enableParallelBuilding:+-j$NIX_BUILD_CORES} CXX=c++ sst-juno-asm
    runHook postBuild
  '';

  enableParallelBuilding = true;

  installPhase = ''
    runHook preInstall
    install -D --mode=755 src/libjuno.so --target-directory=$out/lib/juno
    install -D --mode=755 asm/sst-juno-asm --target-directory=$out/bin
    share=$out/share/juno
    mkdir --parents $share
    cp --recursive "$src/src" tests test $share/
    chmod --recursive u+w $share
    install -D --mode=755 asm/sst-juno-asm --target-directory=$share/asm
    cp asm/Makefile asm/*.cc asm/*.h $share/asm/
    mkdir --parents $out/etc/sst
    cat > $out/etc/sst/juno.conf <<EOF
    [juno]
    juno_LIBDIR=$out/lib/juno
    [SST_ELEMENT_SOURCE]
    juno=$share/src
    [SST_ELEMENT_TESTS]
    juno=$share/tests
    EOF
    runHook postInstall
  '';

  setupHook = ./sst-element-setup-hook.sh;

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    export HOME="$TMPDIR"
    export SST_CONFIG_FILE_PATH="$out/etc/sst/juno.conf"
    # sst-info exits 0 even when the library does not load.
    if sst-info juno 2>&1 | grep 'UNABLE TO PROCESS'; then
      exit 1
    fi
    $out/bin/sst-juno-asm -i test/asm/sum.juno -o sum.bin
    test -s sum.bin
    runHook postInstallCheck
  '';

  passthru.sstConf = "etc/sst/juno.conf";

  meta = {
    description = "Simple processor model and assembler for SST";
    homepage = "https://github.com/sstsimulator/juno";
    license = lib.licenses.bsd3;
    mainProgram = "sst-juno-asm";
    platforms = lib.platforms.unix;
  };
}
