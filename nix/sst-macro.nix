# SST/macro: coarse-grained simulator of MPI applications on HPC networks,
# standalone or as an element library of sst-core.  Not in nixpkgs.
#
# sst-dumpi is a git submodule of the repository; its source comes from the
# sst-dumpi package.  With sst-core, `make install` registers the library
# with sst-register; as in sst-elements.nix this writes a conf fragment in a
# temporary HOME, which goes to $out/etc/sst/sst-macro.conf.
{
  lib,
  stdenv,
  src,
  version,
  autoconf,
  automake,
  libtool,
  python3,
  sst-dumpi,
  sst-core,
  otf2,
  zlib,
  # Element library for sst-core (pysstmac, sstmac-check), as the sqe
  # sst-macro_*_withsstcore scenarios build it.
  sstCoreSupport ? true,
  # OTF2 trace replay.  Only without sst-core: the OTF2 statistics derive
  # from sstmac::StatisticOutput, which the integrated build does not have.
  otf2Support ? !sstCoreSupport,
}:

assert otf2Support -> !sstCoreSupport;

stdenv.mkDerivation {
  pname = if sstCoreSupport then "sst-macro" else "sst-macro-standalone";
  inherit src version;

  nativeBuildInputs = [
    autoconf
    automake
    libtool
    python3
  ]
  ++ lib.optional sstCoreSupport sst-core;

  # The OTF2 link check of sst-dumpi adds -lz.
  buildInputs =
    lib.optional sstCoreSupport sst-core
    ++ lib.optionals otf2Support [
      otf2
      zlib
    ];

  patches = [ ./patches/sst-macro/otf2-3.patch ];

  # bootstrap.sh runs `git submodule update` before autoreconf.  The
  # submodule gets the source and the patches of the sst-dumpi package.
  postPatch = ''
    rmdir sst-dumpi 2>/dev/null || rm -rf sst-dumpi
    cp --recursive ${sst-dumpi.src} sst-dumpi
    chmod --recursive u+w sst-dumpi
    for patch in ${lib.escapeShellArgs sst-dumpi.patches}; do
      patch --directory=sst-dumpi --strip=1 < "$patch"
    done
    patchShebangs bin sst-dumpi/bin
    # The OTF2 test copies traces and makes them writable, including
    # *.backup files that the repository does not have.
    substituteInPlace tests/Makefile.single_tests \
      --replace-fail "chmod u+w traces *.otf2 *.cubex *.cfg *.def *.backup" \
                     "chmod u+w traces *.otf2 *.cubex *.cfg *.def"
  '';

  preConfigure = ''
    libtoolize
    (cd sst-dumpi && libtoolize)
    autoreconf --force --install
  '';

  configureFlags = [
    # The sqe configurations, which avoid std::regex and the unordered
    # container replacements.
    "--disable-regex"
    "--disable-unordered-containers"
  ]
  ++ lib.optional sstCoreSupport "--with-sst-core=${sst-core}"
  # configure passes its flags on to the sst-dumpi subproject, which needs
  # its own switch to build libotf2dump.
  ++ lib.optionals otf2Support [
    "--with-otf2=yes"
    "--enable-otf2"
  ];

  enableParallelBuilding = true;

  preInstall = lib.optionalString sstCoreSupport ''
    export HOME="$TMPDIR/home"
    mkdir --parents "$HOME/.sst"
    touch "$HOME/.sst/sstsimulator.conf"
  '';

  postInstall = lib.optionalString sstCoreSupport ''
    mkdir --parents $out/etc/sst $out/share/sst-macro
    cp --recursive ${src}/tests $out/share/sst-macro/tests
    chmod --recursive u+w $out/share/sst-macro
    substituteInPlace "$HOME/.sst/sstsimulator.conf" \
      --replace-quiet "$PWD/sstmac/install/../../tests" "$out/share/sst-macro/tests" \
      --replace-quiet "$PWD/sstmac/install/../.." "$out/share/sst-macro"
    cp "$HOME/.sst/sstsimulator.conf" $out/etc/sst/sst-macro.conf
  '';

  setupHook = if sstCoreSupport then ./sst-element-setup-hook.sh else null;

  # `make check` runs the unit tests and the reference outputs in tests/.
  doCheck = true;
  checkTarget = "check";

  passthru = lib.optionalAttrs sstCoreSupport { sstConf = "etc/sst/sst-macro.conf"; };

  meta = {
    description = "Coarse-grained simulator of MPI applications on HPC networks";
    homepage = "https://github.com/sstsimulator/sst-macro";
    license = lib.licenses.bsd3;
    mainProgram = "sstmac";
    platforms = lib.platforms.unix;
  };
}
