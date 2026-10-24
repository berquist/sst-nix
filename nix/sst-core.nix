# SST core: the parallel discrete event simulation framework that loads the
# element libraries.  Not in nixpkgs.
#
# Element libraries register in a sstsimulator.conf.  The one in $out is
# read-only, so elements write their own fragment and the setup hook of each
# element package adds it to SST_CONFIG_FILE_PATH (see sst-elements.nix).
{
  lib,
  stdenv,
  src,
  version,
  autoconf,
  automake,
  libtool,
  python3,
  zlib,
  ncurses,
  hdf5-cpp,
  mpi,
  mpiSupport ? true,
  hdf5Support ? true,
  cursesSupport ? true,
  # Test framework dependencies (sst-test-core)
  withTestFramework ? true,
}:

let
  # blessings colours the output, pygments formats it and testtools runs
  # tests concurrently; sst-test-core runs without them but warns.
  pythonEnv = python3.withPackages (
    ps:
    lib.optionals withTestFramework [
      ps.blessings
      ps.pygments
      ps.testtools
    ]
  );
in
stdenv.mkDerivation {
  pname = "sst-core";
  inherit src version;

  nativeBuildInputs = [
    autoconf
    automake
    libtool
    python3
  ]
  ++ lib.optional mpiSupport mpi;

  buildInputs = [
    python3
    zlib
  ]
  ++ lib.optional cursesSupport ncurses
  ++ lib.optional hdf5Support hdf5-cpp
  ++ lib.optional mpiSupport mpi;

  postPatch = ''
    patchShebangs autogen.sh scripts src/sst/core/testingframework
  '';

  preConfigure = ''
    ./autogen.sh
  '';

  configureFlags = [
    "--with-python=${lib.getDev python3}/bin/python3-config"
    "--with-libz=${lib.getDev zlib}"
    # Otherwise configure takes the interpreter next to python3-config, which
    # lacks the test framework packages.  It is the shebang of sst-test-core
    # and sst-test-elements and what `sst-config --PYTHON` prints.
    "PYTHON_EXE=${pythonEnv.interpreter}"
  ]
  ++ lib.optional (!mpiSupport) "--disable-mpi"
  ++ lib.optional mpiSupport "MPICC=${lib.getDev mpi}/bin/mpicc"
  ++ lib.optional mpiSupport "MPICXX=${lib.getDev mpi}/bin/mpicxx"
  ++ lib.optional cursesSupport "--with-ncurses=${lib.getDev ncurses}/bin/ncursesw6-config"
  ++ lib.optional (!cursesSupport) "--without-ncurses"
  ++ lib.optional hdf5Support "--with-hdf5=${lib.getDev hdf5-cpp}"
  ++ lib.optional (!hdf5Support) "--without-hdf5";

  enableParallelBuilding = true;

  # sst-test-core reads the test suites from the testsdir in the installed
  # sstsimulator.conf, which points into the build tree.  Install them and
  # point the conf there instead.
  postInstall = ''
    mkdir --parents $out/share/sst-core
    cp --recursive tests $out/share/sst-core/tests
    substituteInPlace $out/etc/sst/sstsimulator.conf \
      --replace-fail "testsdir=$PWD/src/sst/../../tests" "testsdir=$out/share/sst-core/tests" \
      --replace-fail "sourcedir=$PWD/src/sst/core" "sourcedir=$out/share/sst-core" \
      --replace-fail "builddir=$PWD" "builddir=$out/share/sst-core"
  '';

  # A smoke test of the installed tools.  The full suite (sst-test-core) is
  # passthru.tests.testsuite, since it takes long and starts MPI jobs.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    export HOME="$TMPDIR"
    export PATH="$out/bin:$PATH"
    sst --version
    sst-config --prefix
    sst-info sst.linear > /dev/null
    runHook postInstallCheck
  '';

  passthru = {
    # The interpreter embedded in sst.  Element packages build their Python
    # dependencies with it.
    python = python3;
    inherit mpiSupport;
    mpi = if mpiSupport then mpi else null;
  };

  meta = {
    description = "Structural Simulation Toolkit core: parallel discrete event simulation framework";
    homepage = "https://sst-simulator.org";
    downloadPage = "https://github.com/sstsimulator/sst-core";
    license = lib.licenses.bsd3;
    mainProgram = "sst";
    platforms = lib.platforms.unix;
  };
}
