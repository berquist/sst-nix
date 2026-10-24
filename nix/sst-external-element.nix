# Example of an SST element library built outside sst-elements.  Not in
# nixpkgs.
#
# As in juno.nix, the conf fragment is written here in place of the
# sst-register calls of the Makefile `install` target.
{
  lib,
  stdenv,
  src,
  version,
  sst-core,
}:

stdenv.mkDerivation {
  pname = "sst-external-element";
  inherit src version;

  nativeBuildInputs = [ sst-core ];

  buildPhase = ''
    runHook preBuild
    make -C src libsimpleExternalElement.so
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -D --mode=755 src/libsimpleExternalElement.so \
      --target-directory=$out/lib/sst-external-element
    share=$out/share/sst-external-element
    mkdir --parents $share
    cp --recursive "$src/src" tests $share/
    chmod --recursive u+w $share
    mkdir --parents $out/etc/sst
    cat > $out/etc/sst/sst-external-element.conf <<EOF
    [simpleExternalElement]
    simpleExternalElement_LIBDIR=$out/lib/sst-external-element
    [SST_ELEMENT_SOURCE]
    simpleExternalElement=$share/src
    [SST_ELEMENT_TESTS]
    simpleExternalElement=$share/tests
    EOF
    runHook postInstall
  '';

  setupHook = ./sst-element-setup-hook.sh;

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    export HOME="$TMPDIR"
    export SST_CONFIG_FILE_PATH="$out/etc/sst/sst-external-element.conf"
    # sst-info exits 0 even when the library does not load.
    if sst-info simpleExternalElement 2>&1 | grep 'UNABLE TO PROCESS'; then
      exit 1
    fi
    runHook postInstallCheck
  '';

  passthru.sstConf = "etc/sst/sst-external-element.conf";

  meta = {
    description = "Example SST element library built outside sst-elements";
    homepage = "https://github.com/sstsimulator/sst-external-element";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.unix;
  };
}
