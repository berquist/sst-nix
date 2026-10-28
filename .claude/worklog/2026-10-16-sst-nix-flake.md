---
date: 2026-10-16
slug: sst-nix-flake
status: done
sessions: ["548ac736-45dc-4917-a864-e3e5bf4c6d03"]
touches: ["flake.nix", "flake.lock", "nix/**", "scripts/**", "Justfile", "README.md", ".gitignore", ".envrc", ".editorconfig"]
---

# Nix packages and dev shells for SST

## Ask

Prompts in order.  Answers to questions and plan-mode rejections are marked.
Background task notifications are left out.

1. `/plan`, then:

   > In the current directory I want to create a Nix development shell for
   > all of the main Structural Simulator Toolkit (SST) packages.  All of the
   > packages are cloned into this directory.  Each one should get its own
   > Nix package, but they shouldn't go in the repositories themselves for
   > now; they should be structured so that they can be upstreamed later.
   > You can look at the unrelated 'openchemistry-nix' and 'lanranragi-nix'
   > to understand the general idea.  Specifically for sst-sqe, I'm not sure
   > it should get a package, since the point is to be able to use it to
   > download and compile arbitrary copies of core/elements/macro/etc., but
   > the dev shell should allow running sst-sqe/dev/run-bamboo-like-github.sh
   > as-is.  Elements in particular has a lot of optional dependencies.  They
   > should be marked as optional for the package, but this dev shell should
   > provide them all any just recipe or similar here that builds element
   > should incorporate them.  For these third-party dependencies I expect
   > most will need packacking, which should be done.  If you need sources
   > for any, ask me to clone them.

2. Answers (AskUserQuestion):
   - Sources: "Flake inputs + local override (Recommended)"
   - Pin, CUDA, GPGPU-Sim: "Package all, separate shell (Recommended)"
   - sqe MPI module: "Real OpenMPI 4.1.4 module (Recommended)"
   - Flake location: "This directory (Recommended)"

3. Plan rejected: "You're missing PEBIL for elements"

4. Plan rejected: "Elements has additional Python dependencies: sympy,
   networkx, and matplotlib"

5. Plan approved.  "great, continue with the implementation"

6. "continue"

7. (queued) "For PEBIL note that it also needs a submodule that I've checked
   out which should probably be an additional intermediate package:" with
   the pasted output of `git submodule init external/epa-inst-libs` and
   `git submodule update` in `third-party/PEBIL` (checked out
   `4aa8034ee4f7f139417264ac061cfeb98ca8993a`).

8. Answers (AskUserQuestion):
   - /bin/bash: "Host has /bin/bash"
   - DUMPI and PAPI: "Patch DUMPI to PAPI 7"
   - EPAX and OTF v1: "For EPAX, in addition to not being public, I don't
     think it's required.  For OTF v1, its main download site is down, but
     is available via Spack, like" a `fetchurl` with the TU Dresden URL and
     the Spack source-cache mirror, sha256
     `0a8427360dedb38e8ddca30f14d95f826420c550337c5a79dbb754904e194088`.
   - Remaining clones (gpu-app-collection, Lmod, riscv-isa-sim): "Cloning
     now"

9. (queued) "You can switch from 4.1.4 to the latest 4.1.x if that's easier"

10. Answers (AskUserQuestion):
    - GPGPU-Sim: "accel-sim distribution (Recommended)"
    - Stake: "I will unshallow + clone pk"
    - Intel Pin: "Downloading 3.31"
    - epa-inst-libs ReuseDistance test and Lmod `rt/` tests: "Leave both off
      for now"

11. Answer (AskUserQuestion), balar against CUDA 12: "Patch balar for CUDA 12
    (Recommended)"

12. "sorry, didn't mean to interrupt, keep going"

13. `/worklog` (2026-10-28).  The first attempt failed: the Bash tool could
    not start after a resume.  It worked after a restart.

## Plan

The approved plan, as saved at the end of plan mode.  Headings are moved
down two levels.  The implementation changed some parts; see "Outcome".

### sst-nix: Nix packages and dev shell for SST

#### Context

The SST repos (sst-core, sst-elements, sst-macro, sst-hgcc, juno,
sst-external-element, sst-sqe) are cloned side by side in
`/home/eric/data/development/sst/forks/sst-nix`.  We want one flake here that
gives each SST project its own Nix package (written nixpkgs-style, so it can be
upstreamed later), packages the third-party optional deps of sst-elements, and
gives a dev shell where `sst-sqe/dev/run-bamboo-like-github.sh` runs as-is.
Model: `openchemistry-nix` (overlay, flake inputs for sources, local override
script, Justfile → scripts/, README tables, lint checks).

Decisions taken with the user:
- Sources are non-flake inputs (`github:sstsimulator/<repo>/devel`); a script
  overrides them with `path:./<repo>` to build the local forks.
- Pin, CUDA and GPGPU-Sim are packaged; they go in a separate `.#full` shell and
  `full` recipe variants.  Default shell has every free optional dep.
- sqe gets Lmod plus Nix-generated modulefiles, including a real OpenMPI 4.1.4.
- Flake lives in this directory; SST clones, reference repos and third-party
  clones are gitignored.  The user runs `git init`.

#### Step 0: sources to ask the user to clone (before writing those packages)

Into `third-party/` (gitignored), `git clone --depth 1`, so I can read their
build systems and the sqe patches against them:
- `https://github.com/CMU-SAFARI/ramulator` (sqe pins `7d2e723`, so full clone)
- `https://github.com/CMU-SAFARI/ramulator2` (pins `011ccd7`, full clone)
- `https://github.com/tactcomplabs/gc64-hmcsim` branch `sst-8.0.0-release`
- `https://github.com/sstsimulator/sst-dumpi`
- `https://github.com/purdue-aalp/sst-gpgpusim-external`
- PEBIL (`https://github.com/epanalytics/PEBIL`) and EPAX: Ariel's
  `ariel.frontend.epa` instrumentation tools.  Not configure deps; Ariel uses
  them at run time and its tests check `PEBIL_ROOT` / `EPAX_ROOT`
  (`ariel/tests/testsuite_mpi_Ariel.py:31`, `testsuite_testio_Ariel.py:20`).
  Ask the user for the EPAX source location (may not be public).
- `gpu-app-collection` (`sst_support` branch) for balar tests
  (`GPUAPPS_ROOT`), full shell only.
- OTF v1 (Open Trace Format, TU Dresden): ask the user for a tarball; it is
  obsolete and may have no live source.
- Spike: check first whether nixpkgs `spike` installs `sim.h`, `libfesvr`,
  `libsoftfloat`; if not, ask for `riscv-software-src/riscv-isa-sim`.
Also confirm with `nix eval` whether nixpkgs has `otf2`, `llvmPackages_22`,
`lmod`, `hdf5-cpp`, `spike`.

#### Layout

```
flake.nix  flake.lock  .envrc  .gitignore  .editorconfig  Justfile  README.md
nix/overlay.nix            inputs: final: prev: — wires everything
nix/sst-core.nix           autotools; mpi, python3, zlib, ncurses, hdf5-cpp
nix/sst-elements.nix       all optional deps as `? null` args + enable flags
nix/sst-macro.nix          autotools (bootstrap.sh); uses sst-dumpi pkg, not submodule
nix/sst-hgcc.nix           LLVM 22 libTooling; lit + FileCheck for checks
nix/juno.nix               Makefile; builds libjuno.so + sst-juno-asm
nix/sst-external-element.nix  Makefile example element
nix/sst-with-elements.nix  symlinkJoin + wrapper, like python.withPackages
nix/sst-dumpi.nix  ramulator.nix  ramulator2.nix  goblin-hmcsim.nix
nix/otf.nix  spike-sst.nix (only if override needed)
nix/pebil.nix  epax.nix   Ariel EPA frontends (run-time tools)
nix/intel-pin.nix          requireFile, x86_64-linux, unfree
nix/gpgpu-sim.nix          sst-gpgpusim-external, needs cudaPackages
nix/openmpi_4.nix          openmpi.overrideAttrs → 4.1.4 (for sqe module)
nix/sqe-modulefiles.nix    Lmod .lua files: mpi/openmpi-4.1.4, ccache/ccache-4.12,
                           otf2/otf2-3.1.1, pin/pin-3.31 (full only)
nix/shells.nix             default, full; returns attrset (openchemistry style)
scripts/nix-build-local.sh copy of openchemistry's, with SST input names
scripts/build-elements.sh  local configure/make of ./sst-elements with all deps
scripts/build-core.sh, build-macro.sh, build-hgcc.sh (same pattern)
```

#### flake.nix

- Inputs: `nixpkgs` (nixos-unstable), `systems`, `flake-utils`
  (`inputs.systems.follows`), non-flake `sst-core`, `sst-elements`,
  `sst-macro`, `sst-hgcc`, `juno`, `sst-external-element` (sstsimulator,
  `devel`/`master`).  Third-party sources use `fetchFromGitHub` with `rev` and
  `hash` inside their files, since they are upstream-ready as-is.
- `eachDefaultSystem`: `pkgs = import nixpkgs { overlays = [ self.overlays.default ];
  config.allowUnfreePredicate = <pin, cuda*, gpgpu-sim>; }`.
- `packages`: all of the above; `default = sst-with-elements` (core + elements).
  Pin/CUDA packages via `lib.optionalAttrs (lib.meta.availableOn ...)`.
- `devShells = pkgs.callPackage ./nix/shells.nix { }`.
- `checks = packages minus unfree/requireFile ones // { scripts-lint }`
  (shellcheck + shfmt, as openchemistry).
- `formatter = pkgs.nixfmt`; `// { overlays.default = import ./nix/overlay.nix inputs; }`.
- Version helper `unstableVersion` copied from `openchemistry-nix/nix/overlay.nix`.

#### Package notes

- **sst-core**: `autoreconfHook` won't do (custom autogen); run `./autogen.sh`
  in `preConfigure` after `patchShebangs`.  `--with-python`, `--with-hdf5`,
  `--with-ncurses`, `--with-libz`; `mpiSupport ? true` → `--disable-mpi`.
  Python env with `blessings`, `pygments` for the test framework.
  `sst-test-core` as `installCheck` (may be slow; gated by `doInstallCheck`).
- **sst-elements**: every dep is an arg defaulting to `null`
  (`ramulator ? null`, `pin ? null`, ...) and maps to `--with-x=PATH` or
  `--without-x` explicitly, because configure auto-detects otherwise.
  Registration: sst-register cannot write core's store conf, so set
  `HOME=$TMPDIR`, seed `$HOME/.sst/sstsimulator.conf`, install, then copy the
  element sections to `$out/etc/sst/sst-elements.conf`.  A setup hook does
  `addToSearchPath SST_CONFIG_FILE_PATH $out/etc/sst/sst-elements.conf`
  (core reads `SST_CONFIG_FILE_PATH`, `sst-core/src/sst/core/env/envquery.cc:177`).
  `numpy` must be from core's python.  balar only when cuda + gpgpu-sim given.
  Overlay builds the plain package with no optional deps (upstream default)
  and `sst-elements-full-free` / `sst-elements-full` with all of them.
- **ramulator2**: copies `memHierarchy/membackend/ramulator2/sst_frontend.cpp`
  from the elements source into its tree (per `Instructions.md`), so it takes
  `sst-elements.src` as an arg.  Apply sqe patches from
  `sst-sqe/buildsys/deps/patches/` (vendored into `nix/patches/`).
- **ramulator**, **goblin-hmcsim**: no install target; write `installPhase`
  that keeps the layout configure expects (headers in `src`/`include`, lib).
- **sst-macro**: `bootstrap.sh` does `git submodule`; skip that and link the
  sst-dumpi package source.  Options `--with-sst-core`, `--with-clang` (optional),
  `--with-otf2`.
- **sst-hgcc**: `--with-sst-core --with-sst-elements --with-clang=<llvm 22>
  --with-std=17 --enable-strict-tests`; `make check` with lit/FileCheck.
- **juno**, **sst-external-element**: plain `make -C src`; custom
  `installPhase` with the same HOME/conf trick for `sst-register`.
- **sst-with-elements**: `sst-with-elements.override { elements = [ ... ]; }`
  → wrapped `sst`, `sst-info`, `sst-test-*` with `SST_CONFIG_FILE_PATH` set.
- Every file: header comment, `meta` (description, homepage, license,
  platforms, mainProgram), `sst-` licenses per repo LICENSE.

#### Python dependencies

From a scan of third-party imports in each repo (all must use core's python):

| Repo         | Python packages                                                    |
| ------------ | ------------------------------------------------------------------ |
| sst-core     | blessings, pygments, testtools (concurrent test runs)              |
| sst-elements | numpy, sympy, networkx, matplotlib, galois (merlin `Slimfly.py`)   |
| sst-macro    | numpy, matplotlib, pyyaml, lldb (debug helper, optional)           |
| sst-hgcc     | lit                                                                |

Each package lists its own set as optional args (`withPythonDeps ? true`
style: `propagatedBuildInputs` for run-time, `nativeInstallCheckInputs` for
tests).  The dev shell uses one `python3.withPackages` with the union, and
sst-core is built against that same interpreter.  Missing from nixpkgs →
package under `nix/python/` via `pythonPackagesExtensions` (openchemistry
pattern), e.g. `galois` if absent.

#### Dev shell (`nix/shells.nix`)

- **default**: `inputsFrom = [ sst-core sst-elements-full-free sst-macro sst-hgcc ]`,
  plus autotools, libtool, gnumake, cmake, ninja, ccache, doxygen, git, wget,
  openssl, patch, python3 (the union from "Python dependencies"), llvm 22 tools
  (clang, FileCheck, llvm-config), mpi, lmod, just, shellcheck, shfmt, nixfmt.
  Exports `SST_ELEMENTS_CONFIGURE_FLAGS` built from the same dep list that
  `sst-elements-full-free` uses (single source), `LLVM_ROOT`, `FILECHECK`,
  and `MODULEPATH=${sqe-modulefiles}`.  Test-time tools for sst-test-elements:
  `PEBIL_ROOT`/`EPAX_ROOT` set and `pebil` on PATH, OpenMP (Ariel `OMP_EXE`
  tests), and `pkgsCross` riscv64/mipsel musl gcc so vanadis tests can be
  rebuilt (`MakeTests = True`).  The sst-elements package gets these through
  `passthru.tests`/`nativeInstallCheckInputs`, not as build inputs.  shellHook sources Lmod's init so
  `module` exists; bamboo.sh also sources `/usr/share/lmod/...` paths, which do
  not exist, so the function must be pre-defined and exported (`export -f`
  works because bamboo runs under bash).  Verify this in step "Verification".
- **full**: default + Pin, CUDA, GPGPU-Sim and their flags, `GPUAPPS_ROOT`,
  `pin/pin-3.31` module.

#### Justfile (one-line recipes → scripts/)

`default: @just --list`; `nix-build pkg *args` (local override build),
`check` (`nix flake check -L`), `build-core`, `build-elements`,
`build-elements-full` (runs `nix develop .#full -c scripts/build-elements.sh`),
`build-macro`, `build-hgcc`, `sqe` (runs the bamboo script with log
redirection, as its header says).  Builds go to `build/<repo>` and install to
`install/<repo>`, out of source.  `build-elements.sh` uses
`$SST_ELEMENTS_CONFIGURE_FLAGS`, so the shell and the recipe cannot drift.

#### sqe

No package.  The shell must let `./dev/run-bamboo-like-github.sh` run
unmodified: wget, git, `module` function, `mpi/openmpi-4.1.4` → OpenMPI
4.1.4 (`mpicc`, `mpicxx`, `mpirun`), `gcc`/`g++` on PATH, `python3-config`,
`#!/bin/bash` shebangs (exist on NixOS via `/bin/sh` only — check; if not,
note it and suggest `bash ./dev/...`, since the script is not ours to change).
Network is needed (it clones from GitHub).

#### README.md

Use, shells table, packages table (Package | Source | In nixpkgs?), recipes
table, notes on Pin download (`nix-store --add-fixed`), unfree, sqe.

#### Verification

1. `nixfmt` on every .nix; `shellcheck` + `shfmt --diff` on scripts.
2. `nix flake check -L` (builds core, elements variants, macro, hgcc, juno,
   external element, third-party deps).
3. `just nix-build sst-elements-full-free` against the local forks.
4. `nix develop -c just build-core build-elements`; then
   `sst-info memHierarchy` shows ramulator/goblin backends.
5. `nix develop -c sst-test-core` on the built core.
6. In the shell: `cd sst-sqe && ./dev/run-bamboo-like-github.sh >& bamboo.log`;
   check the log for `ModuleEx avail` success, `mpi/openmpi-4.1.4` load, and
   test results.
7. `.#full` evaluates; builds only after the Pin tarball is added.
8. Offer a worklog at the end; stage files and print the commit command (the
   user commits).

## Out-of-band

- The user cloned the third-party sources into `third-party/` in a separate
  terminal: Ramulator, Ramulator 2, gc64-hmcsim, sst-dumpi, PEBIL,
  gpu-app-collection, Lmod, riscv-isa-sim (later unshallowed) and riscv-pk.
  The user also downloaded the Pin 3.31 tarball.  These commands are not in
  the transcript.
- In `third-party/PEBIL`: `git submodule init external/epa-inst-libs` and
  `git submodule update` (pasted in prompt 7).
- The user ran `git init`, created `flake.lock`, removed the reference repos
  from `.gitignore`, and made the commit `8c3a6ff initial commit`
  (2026-10-23), which has all 45 files below.

## Changes

All in commit `8c3a6ff`.

- `flake.nix`: flake-utils over `systems`; non-flake SST source inputs;
  packages filtered with `lib.meta.availableOn`; unfree predicate (Pin by
  name, CUDA by the "CUDA EULA" license); shells `default` and `full`;
  checks are the packages plus a script lint.
- `nix/overlay.nix`: all packages and variants (`sst-elements`,
  `-full-free`, `-full`; `sst-macro`, `sst-macro-standalone`).
- `nix/shells.nix`: one `shell` function for both shells; one Python with
  the packages of all projects; `SST_ELEMENTS_CONFIGURE_FLAGS` comes from
  the elements package, so the shell and the package cannot drift.
- SST packages: `nix/sst-core.nix`, `nix/sst-elements.nix`,
  `nix/sst-macro.nix`, `nix/sst-hgcc.nix`, `nix/juno.nix`,
  `nix/sst-external-element.nix`.
- Element registration: `nix/sst-element-setup-hook.sh` (adds
  `etc/sst/<pname>.conf` to `SST_CONFIG_FILE_PATH`),
  `nix/sst-with-elements.nix` and `nix/merge-sst-conf.py` (one merged
  `sstsimulator.conf`, because `sst-test-*` read only that file).
- Third-party packages: `nix/sst-dumpi.nix`, `nix/ramulator.nix`,
  `nix/ramulator2.nix`, `nix/goblin-hmcsim.nix`, `nix/otf.nix`,
  `nix/epa-inst-libs.nix`, `nix/pebil.nix`, `nix/intel-pin.nix`,
  `nix/gpgpu-sim.nix`, `nix/lmod.nix`, `nix/openmpi_4.nix`,
  `nix/python/blessings.nix`, `nix/vanadis-cross-compilers.nix`.
- `nix/sqe-modulefiles.nix`: Lmod modules `mpi/openmpi-4.1.4`, `ccache`,
  `otf2`, and `pin/pin-3.31` in the full variant.
- `nix/patches/`: sqe's Ramulator patches; sst-dumpi ports to OTF2 3, MPI 3
  and PAPI 7; sst-macro OTF2 3 callbacks; sst-elements
  `ramulator2-lib-name` and `balar-cuda12`.
- `scripts/build.sh`, `scripts/test.sh`, `scripts/sqe.sh`,
  `scripts/nix-build-local.sh`, `Justfile`: out-of-source local builds into
  `build/` and `install/`, test runs, the sqe run, and flake builds from the
  local checkouts.
- `README.md`: shells, recipes, packages, patches and open items.
- Outside the repo: memory `deps-include-runtime-tools.md`, from the PEBIL
  and Python rejections.

## Outcome

Done.  `nix flake check` passes with every free package built and tested.
`sst-elements-full` (Pin, CUDA 12.9, GPGPU-Sim) builds and passes its install
check.  In the default shell, `module load mpi/openmpi-4.1.4` works, and
`just sqe` ran `run-bamboo-like-github.sh` unchanged: it cloned and built
sst-core and ran `sst-test-core`.  Only 79 of 235 core tests passed there,
because the sandbox has no `/sys` and hwloc and UCX print warnings into the
test output.  This is not yet confirmed on the host.

Changes from the plan, and approaches that did not work:

- Early builds used an impure `.scratch/dev.nix` with `allowUnfree`.  The
  flake replaced it once the packages built.
- `callPackage` fills every argument that exists in pkgs, so `ramulator ?
  null` style optional arguments were always on.  Each optional dependency
  now has an `xSupport ? false` flag.
- sst-elements configure takes `--with-cuda=no` and `--with-gpgpusim=no` as
  paths.  Those flags are left out when off.
- Pin: the plan said `requireFile`.  The package uses `fetchurl` from Intel.
- CUDA 11.7 is gone from nixpkgs.  GPGPU-Sim and balar use CUDA 12.9;
  balar needs the `textureReference` patch (build-tested only).
- Ramulator 1 and 2 both installed `libramulator.so`, so memHierarchy failed
  to load with both.  `sst-info` exits 0 on load failures, so this was not
  seen until the install checks grepped for "UNABLE TO PROCESS".  Fix:
  Ramulator 2 is `libramulator2.so`, and an m4 patch links `-lramulator2`.
- Ramulator's CPU-mode check ran too long; the check runs DRAM mode only.
- zodiac's DUMPI reader uses removed APIs.  `-full-free` has DUMPI off.
- sst-macro OTF2 only builds standalone, so it is a separate package
  (`sst-macro-standalone`).  A getELIName patch was tried and dropped.
- sst-hgcc lit tests all failed until the wrapped `clang` came first in the
  LLVM root and `ps` was on the wrapper PATH.
- The unfree predicate first matched by package name and missed CUDA
  libraries such as `libnpp`.  It now matches the license.
- Open MPI: 4.1.4 was kept (the offer to move to the latest 4.1.x was not
  needed).  Fixes: `container_of` for libfabric 2, no `always_inline` in the
  OFI MTL, the `mpirun` link and `ortecc`/`orte-info` in the 5.x recipe's
  fixup.
- EPAX is skipped (not public, not required).

## Follow-ups

- Stake (miranda `--with-stake`): needs a Spike fork with
  `sim_t::set_sst_func`.  Upstream Spike never had it.  Find the fork.
- zodiac with DUMPI: stale upstream.
- epa-inst-libs `make check` (ReuseDistance) and Lmod `rt/` tests (need
  Hermes) are off.
- gpu-app-collection is a checkout (`GPUAPPS_ROOT`), not a package.
- Run `just sqe` on the host to confirm the core tests pass outside the
  sandbox.
- Proposal (not added): most builds in this session were
  `nix build -L .#<pkg> > .scratch/<pkg>.log 2>&1; tail .scratch/<pkg>.log`.
  A recipe such as `just nix-build-locked <pkg>` that builds the locked
  flake package with the log in `.scratch/` would replace that.
  `just nix-build` already does the same for the local checkouts.
