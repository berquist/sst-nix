# GPGPU-Sim (accel-sim distribution): cycle-level GPU simulator.  The balar
# element of sst-elements runs CUDA programs on it.  Not in nixpkgs.
#
# The dev branch always builds the SST hooks (balar/README.md still says
# `source setup_environment sst`; the argument is ignored now).  configure of
# sst-elements looks for lib/gcc-<CC version>/cuda-<nvcc version>/release
# under the root, with the version of its own compiler, so this is built
# with the default stdenv, not the CUDA backend one.  Needs CUDA, so unfree.
{
  lib,
  stdenv,
  fetchFromGitHub,
  cudaPackages,
  bison,
  flex,
  makedepend,
  which,
  git,
  hostname,
  zlib,
  libGL,
  python3,
}:

let
  cuda = cudaPackages.cudatoolkit;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "gpgpu-sim";
  version = "4.2.0-unstable-2026-08-27";

  src = fetchFromGitHub {
    owner = "accel-sim";
    repo = "gpgpu-sim_distribution";
    rev = "91880c53383d5a6a6742bfb1be2c5f34e39c7871";
    hash = "sha256-VoHi4yWpYe6vXNHNB3t8mfBDSEPwjbSdwwMcqrLWfVs=";
  };

  patches = [ ./patches/gpgpu-sim/sst-no-memory-channels.patch ];

  nativeBuildInputs = [
    bison
    flex
    makedepend
    which
    git
    hostname # setup_environment
    python3
    cuda
  ];

  buildInputs = [
    zlib
    libGL # libcudart.so links -lGL
    cuda
  ];

  postPatch = ''
    patchShebangs .
  '';

  # nixpkgs gives sinpi, cospi and rsqrt (and the float forms) the exception
  # specifier of glibc >= 2.42 in crt/math_functions.hpp and in the device
  # declarations of crt/math_functions.h, but not in the host declarations
  # near the end of math_functions.h.  src/cuda-sim/cuda-math.h includes both
  # inside a namespace, where the two then conflict.  A corrected copy of the
  # three headers comes first on the include path.
  preConfigure = ''
    fix=$TMPDIR/cuda-math-include
    mkdir --parents $fix/crt
    cp ${cuda}/include/math_functions.h $fix/
    cp ${cuda}/include/crt/math_functions.h ${cuda}/include/crt/math_functions.hpp $fix/crt/
    chmod --recursive u+w $fix
    substituteInPlace $fix/crt/math_functions.h \
      --replace-fail "__func__(double rsqrt(double a));" "__func__(double rsqrt(double a) throw());" \
      --replace-fail "__func__(double sinpi(double a));" "__func__(double sinpi(double a) throw());" \
      --replace-fail "__func__(double cospi(double a));" "__func__(double cospi(double a) throw());" \
      --replace-fail "__func__(float rsqrtf(float a));" "__func__(float rsqrtf(float a) throw());" \
      --replace-fail "__func__(float sinpif(float a));" "__func__(float sinpif(float a) throw());" \
      --replace-fail "__func__(float cospif(float a));" "__func__(float cospif(float a) throw());"
    export NIX_CFLAGS_COMPILE="-I$fix ''${NIX_CFLAGS_COMPILE:-}"
  '';

  # setup_environment sets GPGPUSIM_ROOT, GPGPUSIM_CONFIG and the paths the
  # Makefiles use.  It asks git about the (missing) repository for a build
  # string; those commands fail, which must not stop the build.
  configurePhase = ''
    runHook preConfigure
    export CUDA_INSTALL_PATH=${cuda}
    set +e
    source setup_environment
    status=$?
    set -e
    if [[ $status -ne 0 || -z "''${GPGPUSIM_CONFIG:-}" ]]; then
      echo "setup_environment failed" >&2
      exit 1
    fi
    runHook postConfigure
  '';

  enableParallelBuilding = true;

  installPhase = ''
    runHook preInstall
    mkdir --parents $out
    cp --recursive lib configs setup_environment version $out/
    runHook postInstall
  '';

  passthru = rec {
    inherit cuda;
    # CUDA_VERSION_NUMBER of setup_environment: printf "%02u%02u" of 10
    # times the major and 10 times the minor version, so 12090 for 12.9.
    cudaVersionNumber =
      toString (10 * lib.toInt (lib.versions.major cuda.version))
      + lib.fixedWidthNumber 2 (10 * lib.toInt (lib.versions.minor cuda.version));
    # The variables of setup_environment that programs which run on
    # GPGPU-Sim (the balar tests) read at run time.  For CUDA 6 and later
    # the script also sets the PTX_SIM_* and CUOBJDUMP_SIM_FILE ones;
    # without CUOBJDUMP_SIM_FILE, GPGPU-Sim aborts in pruneSectionList.
    runtimeEnv = {
      CUDA_VERSION_NUMBER = cudaVersionNumber;
    }
    // lib.optionalAttrs (lib.versionAtLeast cuda.version "6.0") {
      PTX_SIM_USE_PTX_FILE = "1.ptx";
      PTX_SIM_KERNELFILE = "_1.ptx";
      CUOBJDUMP_SIM_FILE = "jj";
    };
  };

  meta = {
    description = "Cycle-level simulator of GPUs running CUDA and OpenCL workloads";
    homepage = "https://github.com/accel-sim/gpgpu-sim_distribution";
    license = lib.licenses.bsd3;
    platforms = [ "x86_64-linux" ];
  };
})
