# PEBIL: static binary instrumenter for x86_64 ELF programs.  With its
# ArielIntercept tool it makes programs that send their address stream to
# the Ariel element of sst-elements (frontend ariel.frontend.epa, see
# README_FOR_SST.md).  Not in nixpkgs.
#
# Upstream builds in place: $PEBIL_ROOT is the source tree, with bin/ and
# lib/ filled by `make install`, and the epa-inst-libs submodule built into
# lib/.  Here epa-inst-libs is its own package: its source provides the
# headers, its libraries are linked into $out/lib, and $out is PEBIL_ROOT.
{
  lib,
  stdenv,
  fetchFromGitHub,
  gfortran,
  makeWrapper,
  mpi,
  python3,
  perl,
  epa-inst-libs,
}:

stdenv.mkDerivation {
  pname = "pebil";
  version = "3.1.0-unstable-2025-10-22";

  # Branch feature/sst
  src = fetchFromGitHub {
    owner = "epanalytics";
    repo = "PEBIL";
    rev = "d9ea5cd647be7a5088fc0c12ccc04bb1c5682190";
    hash = "sha256-g7iKqTZpxibk5uQL+XFcc/UsDuajQiDKj5yy68tvyg4=";
  };

  # configure checks for the submodule and runs its configure; the
  # Makefile no longer builds it.
  postPatch = ''
    rmdir external/epa-inst-libs 2>/dev/null || rm -rf external/epa-inst-libs
    cp --recursive ${epa-inst-libs.src} external/epa-inst-libs
    chmod --recursive u+w external/epa-inst-libs
    substituteInPlace Makefile.in \
      --replace-fail "SUBDIRS = external/udis86-1.7 external/epa-inst-libs/ReuseDistance external/epa-inst-libs src tools" \
                     "SUBDIRS = external/udis86-1.7 src tools" \
      --replace-fail "tools: src external/udis86-1.7 external/epa-inst-libs/ReuseDistance" \
                     "tools: src external/udis86-1.7" \
      --replace-fail "install: external/epa-inst-libs tools blacklist" \
                     "install: tools blacklist" \
      --replace-fail '	$(MAKE) -C external/epa-inst-libs install' "" \
      --replace-fail '	$(COPY_LIBS)' ""
    patchShebangs scripts
  '';

  nativeBuildInputs = [
    gfortran
    makeWrapper
    mpi
  ];

  buildInputs = [ mpi ];

  configureFlags = [
    # pebil.static needs static libraries of everything.
    "--disable-static"
    # Otherwise decided by the CPU of the build machine.
    "ax_cv_gcc_x86_cpu_supports_avx512f=no"
    "MPICC=mpicc"
    "MPICXX=mpicxx"
    "MPIFC=mpifort"
  ];

  # The Makefiles want PEBIL_ROOT (bashrc sets it) and fill its bin/ and
  # lib/.  Each level calls `make` on the next one without -j.
  preBuild = ''
    export PEBIL_ROOT="$PWD"
  '';
  enableParallelBuilding = false;

  installPhase = ''
    runHook preInstall
    mkdir --parents $out
    cp --recursive bin lib scripts $out/
    # The udis86 disassembler, which bashrc puts on PATH too
    install -D --mode=755 external/udis86-1.7/udcli/udcli $out/bin/udcli
    for library in ${epa-inst-libs}/lib/*.so; do
      ln --symbolic "$library" $out/lib/
    done
    # pebil reads $PEBIL_ROOT/scripts/inputlist for the function blacklist
    # and dlopens lib<Tool>Tool.so from the library path.
    wrapProgram $out/bin/pebil \
      --set-default PEBIL_ROOT $out \
      --prefix LD_LIBRARY_PATH : $out/lib
    runHook postInstall
  '';

  nativeInstallCheckInputs = [
    python3
    perl
  ];

  # Instrument a small program with the basic block counter and run it.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    printf '#include <stdio.h>\nint main(void){ for (int i = 0; i < 3; i++) printf("%%d\\n", i); return 0; }\n' > hello.c
    cc -O0 -o hello hello.c
    $out/bin/pebil --tool BasicBlockCounter --app hello
    LD_LIBRARY_PATH=$out/lib ./hello.jbbinst
    runHook postInstallCheck
  '';

  meta = {
    description = "Static binary instrumenter for x86_64 ELF programs";
    homepage = "https://github.com/epanalytics/PEBIL";
    license = lib.licenses.gpl3Plus;
    mainProgram = "pebil";
    platforms = [ "x86_64-linux" ];
  };
}
