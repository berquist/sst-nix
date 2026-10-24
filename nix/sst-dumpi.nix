# DUMPI: MPI trace library (libdumpi), trace reader (libundumpi) and trace
# converters, from the SST suite.  Not in nixpkgs.
#
# Used by the zodiac element of sst-elements (libundumpi) and built into
# sst-macro, where it is a git submodule; the commit is the one of that
# submodule.
{
  lib,
  stdenv,
  fetchFromGitHub,
  autoconf,
  automake,
  libtool,
  mpi,
  otf2,
  papi,
  python3,
  zlib,
  # libdumpi: the PMPI tracing library, built with the MPI compilers.
  mpiSupport ? true,
  # dumpi2otf2 converter
  otf2Support ? true,
  # Hardware counters in traces
  # Hardware counters in traces
  papiSupport ? stdenv.hostPlatform.isLinux,
}:

stdenv.mkDerivation {
  pname = "sst-dumpi";
  version = "16.0.0-unstable-2026-04-24";

  src = fetchFromGitHub {
    owner = "sstsimulator";
    repo = "sst-dumpi";
    rev = "97d96d9b32f8aa906ca220ed8331a7adedb7881c";
    hash = "sha256-WdCASVwcSo1f9sgCNe9b2LXPFcwZRp9r1IqPMIfblQg=";
  };

  patches = [
    ./patches/sst-dumpi/otf2-3.patch
    ./patches/sst-dumpi/mpi3-test.patch
    ./patches/sst-dumpi/papi-6.patch
  ];

  nativeBuildInputs = [
    autoconf
    automake
    libtool
    # bin/check_const and friends, run by configure
    python3
  ]
  ++ lib.optional mpiSupport mpi;

  buildInputs =
    lib.optional mpiSupport mpi
    # The OTF2 link check adds -lz.
    ++ lib.optionals otf2Support [
      otf2
      zlib
    ]
    ++ lib.optional papiSupport papi;

  preConfigure = ''
    patchShebangs bin
    sh bootstrap.sh
  '';

  configureFlags = [
    (lib.enableFeature mpiSupport "libdumpi")
    (lib.enableFeature mpiSupport "test")
    # "yes" uses the compiler search path, which has the split outputs of otf2.
    (lib.enableFeature otf2Support "otf2")
    (if papiSupport then "--enable-papi=${lib.getDev papi}" else "--disable-papi")
  ]
  ++ lib.optionals mpiSupport [
    "CC=mpicc"
    "CXX=mpicxx"
  ];

  enableParallelBuilding = true;

  # The converters on the trace of tests/traces, against its text dump.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    # -a prints everything, as in the reference; its start time is in US
    # Pacific time.
    TZ=PST8 $out/bin/dumpi2ascii -a tests/traces/testtrace-0000.bin > testtrace-0000.txt
    diff testtrace-0000.txt tests/traces/testtrace-0000.txt
    runHook postInstallCheck
  '';

  meta = {
    description = "MPI trace library and tools from the Structural Simulation Toolkit";
    homepage = "https://github.com/sstsimulator/sst-dumpi";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.unix;
  };
}
