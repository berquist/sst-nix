# sst-nix

Nix packages and development shells for the Structural Simulation Toolkit
(SST): sst-core, sst-elements, sst-macro, sst-hgcc, juno and
sst-external-element, with the third-party libraries that sst-elements can
use.  The package files in `nix/` are written in nixpkgs style, so that they
can move upstream later.

The SST checkouts sit next to this flake (`sst-core/`, `sst-elements/`, ...)
and are ignored by git.  The flake builds the upstream sources pinned in
`flake.lock`; `just nix-build` builds the local checkouts instead.

## Use

```console
$ direnv allow            # or: nix develop
$ just                    # list the recipes
$ just build-all          # core, elements, macro, hgcc, juno, external element
$ just test elements      # sst-test-elements against install/
```

## Shells

| Shell     | Command              | Use                                                        |
| --------- | -------------------- | ---------------------------------------------------------- |
| `default` | `nix develop`        | All free dependencies; local builds, test suites, sst-sqe  |
| `full`    | `nix develop .#full` | `default` plus Intel Pin, CUDA 12.9 and GPGPU-Sim (unfree) |

Both shells provide:

- every build input of sst-core, sst-elements (all optional libraries),
  sst-macro, sst-hgcc and sst-dumpi;
- `SST_ELEMENTS_CONFIGURE_FLAGS`, the configure flags of the
  `sst-elements-full-free` (or `sst-elements-full`) package, which
  `scripts/build.sh` passes to sst-elements;
- one Python with the packages of all projects (table below), also on
  `PYTHONPATH` for the interpreter that `sst` embeds;
- LLVM 22 (`LLVM_ROOT`, `FILECHECK`) for sst-hgcc;
- Lmod with `MODULEPATH` at the sqe modulefiles, and the `module` function;
- PEBIL (`PEBIL_ROOT`) and the riscv64/mipsel musl cross compilers, which
  the Ariel and Vanadis test suites use;
- in `full`: `CUDA_INSTALL_PATH`, `GPGPUSIM_ROOT`, `INTEL_PIN_DIRECTORY`, and
  `GPUAPPS_ROOT` at `third-party/gpu-app-collection` when that checkout
  exists (balar's tests build its programs in place).

| Project      | Python packages                            |
| ------------ | ------------------------------------------ |
| sst-core     | blessings, pygments, testtools             |
| sst-elements | numpy, sympy, networkx, matplotlib, galois |
| sst-macro    | pyyaml                                     |
| sst-hgcc     | lit                                        |

## Recipes

| Recipe                       | What it does                                              |
| ---------------------------- | --------------------------------------------------------- |
| `just build <project>`       | Configure, build and install one checkout into `install/` |
| `just build-all`             | The same for all six projects, in order                   |
| `just build-elements-full`   | sst-elements with Pin and CUDA, in the `full` shell       |
| `just test <core\|elements>` | `sst-test-core` or `sst-test-elements` against `install/` |
| `just sqe [log]`             | `sst-sqe/dev/run-bamboo-like-github.sh`, output to a log  |
| `just nix-build [package]`   | Build a flake package from the local checkouts            |
| `just check`                 | `nix flake check`                                         |

Local builds are out of source in `build/<project>` and install into
`install/<project>`.  Element libraries register with
`install/sst-core/etc/sst/sstsimulator.conf`, as in a normal installation.

## Packages

| Package                   | Source                                     | In nixpkgs | Notes                                              |
| ------------------------- | ------------------------------------------ | ---------- | -------------------------------------------------- |
| `sst-core`                | sstsimulator/sst-core `devel`              | no         | MPI, HDF5, ncurses; installs its test suites       |
| `sst-elements`            | sstsimulator/sst-elements `devel`          | no         | No optional libraries, as upstream's default       |
| `sst-elements-full-free`  | same                                       | no         | All free optional libraries (the shell's set)      |
| `sst-elements-full`       | same                                       | no         | Also Pin and CUDA/GPGPU-Sim; unfree                |
| `sst-macro`               | sstsimulator/sst-macro `devel`             | no         | Element library for sst-core                       |
| `sst-macro-standalone`    | same                                       | no         | Without sst-core, with OTF2 trace replay           |
| `sst-hgcc`                | sstsimulator/sst-hgcc `devel`              | no         | LLVM 22 libTooling                                 |
| `juno`                    | sstsimulator/juno `master`                 | no         |                                                    |
| `sst-external-element`    | sstsimulator/sst-external-element `master` | no         |                                                    |
| `sst-with-elements`       | (wrapper)                                  | no         | sst-core plus chosen elements, see below           |
| `sst-dumpi`               | sstsimulator/sst-dumpi                     | no         | Patched for OTF2 3, MPI 3 and PAPI 6+              |
| `ramulator`               | CMU-SAFARI/ramulator, sqe's commit         | no         | sqe's patches                                      |
| `ramulator2`              | CMU-SAFARI/ramulator2, sqe's commit        | no         | With the SST frontend; library is libramulator2.so |
| `goblin-hmcsim`           | tactcomplabs/gc64-hmcsim                   | no         |                                                    |
| `otf`                     | OTF 1.12.5 (Spack source cache)            | no         | Python 3.13 and SWIG 4.3 fixes                     |
| `epa-inst-libs`           | epanalytics/epa-inst-libs                  | no         | PEBIL's runtime libraries, with the Ariel frontend |
| `pebil`                   | epanalytics/PEBIL `feature/sst`            | no         | x86_64 only                                        |
| `intel-pin`               | Intel Pin 3.31                             | no         | Unfree, x86_64 only                                |
| `gpgpu-sim`               | accel-sim/gpgpu-sim_distribution `dev`     | no         | CUDA 12.9; unfree through CUDA                     |
| `lmod`                    | TACC/Lmod 9.4.5                            | no         |                                                    |
| `openmpi_4`               | Open MPI 4.1.4                             | 5.x only   | The `mpi/openmpi-4.1.4` module of sqe              |
| `sqe-modulefiles`         | (generated)                                | no         | Lmod modulefiles for bamboo.sh                     |
| `vanadis-cross-compilers` | nixpkgs cross gcc                          | parts      | `riscv64-linux-musl-gcc`, `mipsel-linux-musl-gcc`  |
| `blessings`               | PyPI                                       | no         | Python package for the sst-core test framework     |

### `sst-with-elements`

`sst` finds element libraries through `sstsimulator.conf` files: the one in
the sst-core prefix, `~/.sst/sstsimulator.conf`, and every file in
`SST_CONFIG_FILE_PATH`.  The prefix of sst-core is read-only in the store,
so each element package writes its own fragment to `etc/sst/<pname>.conf`,
and its setup hook adds that file to `SST_CONFIG_FILE_PATH` in Nix builds
and shells.  `sst-with-elements` merges the fragments into one
`etc/sst/sstsimulator.conf` and wraps `sst`, `sst-info`, `sst-config` and
`sst-register`, like `python3.withPackages`:

```nix
{ pkgs }:
pkgs.sst-with-elements.override {
  elements = [
    pkgs.sst-elements-full-free
    pkgs.juno
    pkgs.sst-external-element
  ];
}
```

`sst-test-elements` reads only `<bindir>/../etc/sst/sstsimulator.conf`, which
is why the merged file exists.  The test suites of sst-elements are in its
`testsuite` output (not `tests`, which would clash with `passthru.tests`).

## sst-sqe

sst-sqe has no package: it downloads and builds arbitrary versions of the
other repositories.  In the default shell,

```console
$ just sqe
```

runs `sst-sqe/dev/run-bamboo-like-github.sh` unchanged.  A test run from
this setup cloned and built sst-core with Open MPI 4.1.4 from the module
and ran `sst-test-core`.  It needs network
access (bamboo.sh clones from GitHub), and it loads `mpi/openmpi-4.1.4`
through Lmod.  The modulefiles also offer `ccache` and `otf2` under their
real versions, and `pin/pin-3.31` in the `full` shell.

## Patches and deviations

| Package      | Change                                                                          |
| ------------ | ------------------------------------------------------------------------------- |
| sst-dumpi    | OTF2 3 API (one argument more in three calls); MPI-3 calls in the test          |
| sst-dumpi    | perfctrs.c ported from PAPI's removed high-level API to event sets              |
| ramulator2   | sqe's `.template as<T>()` fix as `substituteInPlace` (CRLF source)              |
| ramulator2   | yaml-cpp 0.7.0 `#include <cstdint>`; library renamed `libramulator2.so`         |
| otf          | `PyEval_CallObject`, `SWIG_Python_AppendOutput`, relative import in Python      |
| openmpi_4    | `container_of` for libfabric 2; no `always_inline` in the OFI MTL               |
| openmpi_4    | 4.1-only files (`ortecc`, `orte-info`, `mpirun` link) in the 5.x recipe's fixup |
| gpgpu-sim    | Corrected copy of CUDA's math headers (nixpkgs' glibc 2.42 patch is partial)    |
| lmod         | `stat` from coreutils in `init/bash`                                            |
| sst-elements | memHierarchy links Ramulator 2 as `-lramulator2` (with ramulator2Support)       |
| sst-elements | balar: CUDA 11 `struct textureReference` when CUDA >= 12 (full variant only)    |
| sst-elements | `-Wno-error=non-c-typedef-for-linkage` for the Ariel pintool (Pin headers)      |
| intel-pin    | `range.m_base` typo in `extras/components/include/util/range.hpp`               |
| sst-macro    | sst-dumpi submodule replaced by the sst-dumpi package source and patches        |
| sst-macro    | OTF2 3 callback signatures in the trace replay; no `*.backup` in a test rule    |

## Not done yet

| Item                            | Why                                                                        |
| ------------------------------- | -------------------------------------------------------------------------- |
| Stake (miranda, `--with-stake`) | Needs a Spike fork with `sim_t::set_sst_func`; upstream Spike never had it |
| EPAX                            | Not public                                                                 |
| zodiac with DUMPI               | Reader uses the removed `loadSubComponent` and an old libundumpi call      |
| sst-macro OTF2 with sst-core    | Upstream code only builds standalone (`sst-macro-standalone` has it)       |
| epa-inst-libs `make check`      | ReuseDistance test is stale upstream (trips a newer assertion)             |
| Lmod `rt/` tests                | Need TACC's Hermes (`tm`)                                                  |
