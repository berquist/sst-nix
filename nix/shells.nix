# Development shells for the SST checkouts in this directory.
#
#   default  Every free dependency: build sst-core, sst-elements (with all
#            free optional libraries), sst-macro, sst-hgcc, juno and the
#            external element from source, run their test suites, and run
#            sst-sqe/dev/run-bamboo-like-github.sh.
#   full     default plus the unfree ones: Intel Pin, CUDA and GPGPU-Sim.
#
# flake.nix also calls this file with the Clang package set (clang.nix) for
# its clang shell.
{
  lib,
  pkgs,
  stdenv,
  mkShell,
  # Compiler of the local builds.  scripts/build.sh reads it from
  # SST_TOOLCHAIN and puts the builds other than GCC in build-<toolchain>/
  # and install-<toolchain>/.
  toolchain ? "gcc",
  # OMPI_CC and OMPI_CXX, so that mpicc and mpicxx use the compiler of
  # stdenv (see clang.nix).
  mpiCompilerEnv ? { },
  python3,
  llvmPackages_22,
  mpi,
  lmod,
  sst-core,
  sst-elements-full-free,
  sst-elements-full,
  sst-macro,
  sst-macro-standalone,
  sst-hgcc,
  sst-dumpi,
  sqe-modulefiles,
  sqe-modulefiles-full,
  vanadis-cross-compilers,
  pebil,
}:

let
  llvm = llvmPackages_22;
  havePebil = lib.meta.availableOn pkgs.stdenv.hostPlatform pebil;

  # The Python packages of all projects, in the interpreter that sst-core
  # embeds (see the README table).
  python = python3.withPackages (
    ps:
    with ps;
    [
      # sst-core test framework
      blessings
      pygments
      testtools
      # sst-macro
      pyyaml
      # sst-hgcc
      lit
      # lint and type checks of sst-core (pyproject.toml)
      mypy
      ruff
    ]
    ++ sst-elements-full-free.pythonDeps ps
  );

  shell =
    {
      elements,
      modulefiles,
      extraEnv ? { },
      extraShellHook ? "",
    }:
    (mkShell.override { inherit stdenv; }) {
      inputsFrom = [
        sst-core
        elements
        sst-macro
        sst-macro-standalone
        sst-hgcc
        sst-dumpi
      ];

      packages = [
        python
        mpi
        lmod
        vanadis-cross-compilers
        llvm.clang
        llvm.llvm # FileCheck
        llvm.llvm.dev # llvm-config
      ]
      # Ariel EPA frontend tests (ariel/tests/testsuite_*_Ariel.py)
      ++ lib.optional havePebil pebil
      ++ (with pkgs; [
        # Build
        autoconf
        automake
        libtool
        gnumake
        cmake
        ninja
        pkg-config
        ccache
        gdb
        # Used by sst-sqe/buildsys/bamboo.sh
        git
        wget
        openssl
        patch
        which
        bc
        procps
        # Docs
        doxygen
        # Tasks and lint
        just
        shellcheck
        shfmt
        nixfmt
      ]);

      env = {
        # scripts/build.sh configures sst-elements with these; they are the flags
        # of the sst-elements-full(-free) package.
        SST_ELEMENTS_CONFIGURE_FLAGS = lib.concatStringsSep " " elements.sstConfigureFlags;
        # sst-hgcc and bamboo.sh (hgcc scenarios)
        LLVM_ROOT = "${sst-hgcc.llvmRoot}";
        FILECHECK = "${llvm.llvm}/bin/FileCheck";
        # bamboo.sh loads mpi/openmpi-4.1.4 and friends with `module load`.
        MODULEPATH = "${modulefiles}";
        SST_TOOLCHAIN = toolchain;
      }
      // mpiCompilerEnv
      // lib.optionalAttrs havePebil {
        # The Ariel EPA tests run when this directory exists.
        PEBIL_ROOT = "${pebil}";
      }
      // extraEnv;

      # Lmod's init defines and exports the `module` function, so that
      # bamboo.sh, a child bash, has it.  The embedded interpreter of sst does
      # not see the packages of `python`, so PYTHONPATH carries them.
      # The setup hook of the sst-elements package (an input of sst-hgcc) sets
      # SST_CONFIG_FILE_PATH; the local builds register in install/ instead.
      shellHook = ''
        unset SST_CONFIG_FILE_PATH
        source ${lmod.initDir}/bash
        export PYTHONPATH="${python}/${python.sitePackages}''${PYTHONPATH:+:$PYTHONPATH}"
      ''
      + extraShellHook;
    };
in
{
  default = shell {
    elements = sst-elements-full-free;
    modulefiles = sqe-modulefiles;
  };

  full = shell {
    elements = sst-elements-full;
    modulefiles = sqe-modulefiles-full;
    # What balar's and ariel's tests read.
    extraEnv = {
      CUDA_INSTALL_PATH = "${sst-elements-full.deps.cuda}";
      GPGPUSIM_ROOT = "${sst-elements-full.deps.gpgpu-sim}";
      INTEL_PIN_DIRECTORY = "${sst-elements-full.deps.intel-pin}";
    };
    # The balar tests build the CUDA programs of gpu-app-collection in place
    # and download their data, so it is a checkout, not a package.
    extraShellHook = ''
      if [[ -d "$PWD/third-party/gpu-app-collection" ]]; then
        export GPUAPPS_ROOT="$PWD/third-party/gpu-app-collection"
      fi
    '';
  };
}
