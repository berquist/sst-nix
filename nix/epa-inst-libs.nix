# epa-inst-libs: the run-time instrumentation libraries of PEBIL (address
# stream, counters, timers, reuse distance), including the Ariel frontend
# that sends the address stream of an instrumented program to SST.  Not in
# nixpkgs.
#
# Upstream it is a git submodule of PEBIL (external/epa-inst-libs), whose
# configure passes it MPI and install settings through the environment.
# This package builds it alone, in the same directory layout, since its
# Makefile refers to ../../external/epa-inst-libs.  pebil.nix uses the
# headers and libraries.
{
  lib,
  stdenv,
  fetchFromGitHub,
  mpi,
  papi,
  sst-core,
  sst-elements,
  # Ariel frontend (ArielFrontend.cpp), for ariel.frontend.epa
  sstSupport ? true,
  # libpapifunc: hardware counters
  papiSupport ? stdenv.hostPlatform.isLinux,
}:

stdenv.mkDerivation {
  pname = "epa-inst-libs";
  version = "1.0-unstable-2025-10-22";

  # Branch feature/sst, the submodule commit of PEBIL d9ea5cd.
  src = fetchFromGitHub {
    owner = "epanalytics";
    repo = "epa-inst-libs";
    rev = "4aa8034ee4f7f139417264ac061cfeb98ca8993a";
    hash = "sha256-3uKXGybpKpyEY7ul59hxiKLBm5YkuduJQ+hST8QwDko=";
  };

  postUnpack = ''
    mkdir --parents pebil/external
    mv "$sourceRoot" pebil/external/epa-inst-libs
    sourceRoot=pebil/external/epa-inst-libs
  '';

  nativeBuildInputs = [ mpi ];

  buildInputs = [ mpi ] ++ lib.optional papiSupport papi ++ lib.optional sstSupport sst-core;

  # What PEBIL's configure exports to this one.
  env = {
    MPICC = "mpicc";
    MPICXX = "mpicxx";
    MPI_FLAGS = "-DHAVE_MPI";
    MPI_CXXFLAGS = "-std=gnu++11 -DHAVE_UNORDERED_MAP";
    INST_LIBS_LIBDIR = "${placeholder "out"}/lib";
    INST_LIBS_BINDIR = "${placeholder "out"}/bin";
    PEBIL_PAPI_BUILD = if papiSupport then "yes" else "no";
    PEBIL_PAPI_PATH = lib.optionalString papiSupport "${lib.getDev papi}";
  };

  configureFlags = lib.optionals sstSupport [
    "--with-sst-core=${sst-core}"
    # Only the Ariel headers of the source tree are used.
    "--with-sst-elements=${sst-elements.src}"
  ];

  enableParallelBuilding = true;

  preBuild = ''
    mkdir --parents $out/lib $out/bin
    make -C ReuseDistance ''${enableParallelBuilding:+-j$NIX_BUILD_CORES} libReuseDistance.so
    install -D --mode=755 ReuseDistance/libReuseDistance.so --target-directory=$out/lib
  '';

  # ReuseDistance has `make check`, but it fails upstream: test/test.cpp
  # creates SpatialLocality(1024, size * 2) for sizes over 512, which the
  # assertion in SpatialLocality::Init (window >= bin size) rejects.
  # TODO: fix the test (open question in README.md).
  doCheck = false;
  checkPhase = ''
    runHook preCheck
    make -C ReuseDistance check
    runHook postCheck
  '';

  # `make` writes the libraries to $out/lib already.
  installPhase = ''
    runHook preInstall
    install -D --mode=644 *.h *.hpp --target-directory=$out/include/epa-inst-libs
    install -D --mode=644 ReuseDistance/*.hpp --target-directory=$out/include/epa-inst-libs/ReuseDistance
    rm -f $out/lib/*.o $out/lib/*.O
    runHook postInstall
  '';

  meta = {
    description = "Run-time instrumentation libraries of the PEBIL binary instrumenter";
    homepage = "https://github.com/epanalytics/epa-inst-libs";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
  };
}
