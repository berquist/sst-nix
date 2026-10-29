# Packages for the SST projects and the dependencies nixpkgs lacks.
# `inputs` are the flake inputs; the SST source inputs are not flakes.
inputs: final: prev:
let
  # nixpkgs-style version for a source taken from a branch.
  unstableVersion =
    base: src: "${base}-unstable-${builtins.substring 0 8 (src.lastModifiedDate or "19700101")}";
in
{
  sst-core = final.callPackage ./sst-core.nix {
    src = inputs.sst-core;
    version = unstableVersion "16.0.0" inputs.sst-core;
  };

  # Upstream default: no optional third-party dependencies.
  sst-elements = final.callPackage ./sst-elements.nix {
    src = inputs.sst-elements;
    version = unstableVersion "16.0.0" inputs.sst-elements;
  };

  # Every free optional dependency.  The dev shell takes its configure flags
  # from this package (passthru.sstConfigureFlags), so the two cannot drift.
  sst-elements-full-free = final.sst-elements.override {
    pname = "sst-elements-full-free";
    pythonSupport = true;
    otf2Support = true;
    otfSupport = true;
    # zodiac's DUMPI reader does not build: it calls the removed
    # loadSubComponent and an old undumpi_read_stream signature.
    dumpiSupport = false;
    ramulatorSupport = true;
    ramulator2Support = true;
    goblinHmcsimSupport = true;
  };

  # Also the unfree ones: Intel Pin (ariel, prospero) and CUDA with
  # GPGPU-Sim (balar).
  sst-elements-full = final.sst-elements-full-free.override {
    pname = "sst-elements-full";
    pinSupport = true;
    cudaSupport = true;
    cudaPackages = final.cudaPackages_12_9;
  };

  sst-macro = final.callPackage ./sst-macro.nix {
    src = inputs.sst-macro;
    version = unstableVersion "16.0.0" inputs.sst-macro;
  };

  # Without sst-core, and with OTF2 trace replay.
  sst-macro-standalone = final.sst-macro.override { sstCoreSupport = false; };

  sst-hgcc = final.callPackage ./sst-hgcc.nix {
    src = inputs.sst-hgcc;
    version = unstableVersion "0" inputs.sst-hgcc;
    sst-elements = final.sst-elements;
    llvmPackages = final.llvmPackages_22;
  };

  juno = final.callPackage ./juno.nix {
    src = inputs.juno;
    version = unstableVersion "16.0.0" inputs.juno;
  };

  sst-external-element = final.callPackage ./sst-external-element.nix {
    src = inputs.sst-external-element;
    version = unstableVersion "16.0.0" inputs.sst-external-element;
  };

  sst-with-elements = final.callPackage ./sst-with-elements.nix {
    elements = [ final.sst-elements ];
  };

  # Optional dependencies of sst-elements
  epa-inst-libs = final.callPackage ./epa-inst-libs.nix { };
  goblin-hmcsim = final.callPackage ./goblin-hmcsim.nix { };
  gpgpu-sim = final.callPackage ./gpgpu-sim.nix { cudaPackages = final.cudaPackages_12_9; };
  intel-pin = final.callPackage ./intel-pin.nix { };
  otf = final.callPackage ./otf.nix { };
  pebil = final.callPackage ./pebil.nix { };
  sst-dumpi = final.callPackage ./sst-dumpi.nix { };
  ramulator = final.callPackage ./ramulator.nix { };
  ramulator2 = final.callPackage ./ramulator2.nix {
    sstFrontend = "${inputs.sst-elements}/src/sst/elements/memHierarchy/membackend/ramulator2/sst_frontend.cpp";
  };

  lmod = final.callPackage ./lmod.nix { };

  # The module that sst-sqe/dev/run-bamboo-like-github.sh loads.
  openmpi_4 = final.callPackage ./openmpi_4.nix { };

  sqe-modulefiles = final.callPackage ./sqe-modulefiles.nix { };
  # With the pin/pin-3.31 module, for the full shell.
  sqe-modulefiles-full = final.sqe-modulefiles.override { pinSupport = true; };

  vanadis-cross-compilers = final.callPackage ./vanadis-cross-compilers.nix { };

  balar-riscv-toolchain = final.callPackage ./balar-riscv-toolchain.nix { };

  # CUDA 11.8 for the GPU apps of the balar tests (gpu-app-collection).
  # Their kmeans uses texture references, which CUDA 12 removed.  balar and
  # GPGPU-Sim stay on CUDA 12.9: balar's packets have the CUDA 11 layout of
  # textureReference (patches/sst-elements/balar-cuda12.patch).
  balar-gpu-apps-cuda =
    (import inputs.nixpkgs-cuda11 {
      localSystem = final.stdenv.hostPlatform.system;
      config = {
        inherit (final.config) allowUnfree allowUnfreePredicate;
      };
    }).cudaPackages_11_8.cudatoolkit;

  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (pyfinal: _pyprev: {
      blessings = pyfinal.callPackage ./python/blessings.nix { };
    })
  ];
}
