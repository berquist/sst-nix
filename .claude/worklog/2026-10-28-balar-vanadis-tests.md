---
date: 2026-10-28
slug: balar-vanadis-tests
status: done
sessions: ["0a105648-4ea4-43af-8618-c341d43afb68"]
touches: ["flake.nix", "flake.lock", "nix/**", "scripts/build.sh", "Justfile", "sst-elements/src/sst/elements/balar/**", "sst-elements/src/sst/elements/vanadis/**"]
---

# Full shell: Pin 3.31 with GCC 16, then the balar and Vanadis tests

The session ran from 2026-10-28 to 2026-10-29.  It started with a Pin build
error and became a chain of test fixes, until `just test elements -w
'*balar*'` passed in the `full` shell.

## Ask

Prompts in order.  Pasted logs are shown as `[paste: ...]` with what they
contained; the words around them are verbatim.  "approved" answers a
`.scratch/` proposal (patch-review).

1. GCC 16 isn't compiling elements against Pin 3.31; is there an easy patch?
   `[paste: pinsync.hpp -Wnon-c-typedef-for-linkage errors]`
2. Progress: `[paste: balar error, textureReference with CUDA 12]`
3. So all the patches in nix/patches are only applied when running builds
   through Nix?
4. yes, make build.sh apply the patches
5. The build is successful; now when trying to test: `[paste: test engine
   assertion]`
6. AssertionError: ('testsuite_default_balar.testcase_balar_simple.test_balar_vanadis_clang_vecadd', [], None)
7. yes, fix the skipIf decorators too
8. Test results: `[paste: many failures, libmemHierarchy undefined Ramulator
   symbol]`
9. yes, make the build.sh updates
10. PEBIL tests are failing: /home/eric/data/development/sst/forks/sst-nix/sst-elements/src/sst/elements/ariel/frontend/simple/examples/stream/stream.arielinst: error while loading shared libraries: libaddressstream.so: cannot open shared object file: No such file or directory
11. `[paste: rdmaNic FAULT and balar vectorAdd directory error]`
12. `[paste: test results]`
13. 1. `[paste: objdump around 0x10194]` 2. `[paste: balar debug log]`
14. First, rdmaNic: `[paste: .err/.out tails, DECODE_FAULT at 0x101a8]`
15. Read "objdump.log"
16. yes, add the patch to nix/patches/sst-elements along with a description
    suitable for a commit message.  Will this break older musl versions?
    Can you say what the musl version is where this behavior changed?
17. now do both parts of the balar fix
18. approved
19. read "log-balar-riscv-toolchain"
20. `[paste: clang -v output]` and it's not picking up any balar tests
21. `[paste: test log, testsuite_log-balar-riscv-toolchain.py]`
22. yes, apply the Justfile fix
23. `[paste: libcudart build failed]`
24. `[paste: balar_cuda12_compat.h missing]`
25. `[paste: rodinia make failed]`
26. `[paste: manual backprop make, C23 errors from host gcc]`
27. switched to sst_support, read setup_environment
28. `[paste: full shell variables, SST=1 CUDA=12.9]`
29. `[paste: rodinia make result 2, no output]`
30. `[paste: manual backprop make, link error for -lcudart_vanadis]`
31. I think it's getting further: `[paste: rodinia make up to kmeans]`
32. `[paste: kmeans "no template named 'texture'"]`
33. (answer to a question) CUDA 11 for the GPU apps
34. approved
35. It's hanging here: `[paste: rodinia make done]` how can I figure out
    what it's hanging on?
36. pstree: invalid option -- '-'
37. pstree: invalid option -- 'a'
38. it's wget, the file is growing
39. Is there a way to pre-download this using Nix?
40. 1. path is '/nix/store/g0sjnjn32kd1j0v1gk64pcmjnb2lrj0m-all.gpgpu-sim-app-data.tgz'
    0yciw1nbva9z17kvalxsp14ziwlazia5z54fm5269wacyl1i77yr
    2. Progress: `[paste: data step killed, result -9]`
41. approved
42. `[paste: vecadd stats file missing]`
43. approved
44. read "build/test-elements/sst_test_outputs/run_data/test_gpgpu_vecadd.err"
45. `[paste: vecadd line count diff]`
46. yes, add the patch to nix/patches/sst-elements
47. read "build/test-elements/sst_test_outputs/run_data/test_gpgpu_vecadd.err" but also the out file
48. approved
49. still failing
50. still failing
51. (sent mid-turn) How much of this is because of CUDA 12 instead of CUDA
    11?  I wonder if everything should just use 11, since that's what the
    gpu apps require.
52. cloned it, look at the history
53. apply it
54. still failing
55. that was my fault; I reran balar and it passes
56. yes, write the worklog

## Plan

No plan mode.  Each multi-file change went through `.scratch/` first
(patch-review) and was applied on "approved"; one-line fixes went in
directly.

## Out-of-band

The user ran all builds and tests in a separate terminal and pasted the
results, so the transcript has the output but not the exact commands.  The
usual ones were `just build-elements-full`, `just build sst-elements`, `just
test elements -w '*balar*'`, `just test elements -w '*rdmaNic*'` and `nix
develop .#full --command ...`.  Others that mattered:

- `git revert 25a9079` (the wrong rv64g change, now 7a71a90).
- `git checkout sst_support` in `third-party/gpu-app-collection` (it was on
  `dev`).
- `nix-prefetch-url --type sha256 "file://$HOME/all.gpgpu-sim-app-data.tgz"`
  from a hard link made while `wget` ran, which gave the fetchurl hash
  `0yciw1nbva9z17kvalxsp14ziwlazia5z54fm5269wacyl1i77yr` without a second
  download.
- `rm build/sst-elements/src/sst/elements/memHierarchy/libmemHierarchy.la`
  and `rm build/sst-elements/src/sst/elements/balar/libbalar.la`, to force
  stale libraries to link again.
- Clone of `accel-sim/gpgpu-sim_distribution` (full history) into
  `third-party/gpgpu-sim_distribution`.

## Changes

Commits in sst-nix (the user made them):

- 06e658f: `nix/intel-pin.nix` names the three anonymous `typedef struct`s
  of `pinsync.hpp`, so GCC 15+ does not warn
  (`-Wnon-c-typedef-for-linkage`, an error with `-Werror`).  The
  `NIX_CFLAGS_COMPILE` workaround in `nix/sst-elements.nix` went away; it
  did not reach the dev shell anyway.
- 2125158, d793453: `scripts/build.sh` applies `nix/patches/<project>` to
  the local checkouts (skips patches already in), and removes the build
  tree when it applies a new patch, because make does not relink a library
  when only its link flags change.
- e550c78: `nix/shells.nix` puts `${pebil}/lib` on `LD_LIBRARY_PATH`, as
  PEBIL's bashrc does; instrumented programs need `libaddressstream.so`.
- 25a9079, reverted in 7a71a90: an rv64g cross toolchain, from a wrong
  theory (see Outcome).
- 88d3037, 1963fb9: `nix/balar-riscv-toolchain.nix` (riscv64 glibc GNU
  toolchain in the riscv-gnu-toolchain layout that balar's Makefiles
  expect), `LLVM_INSTALL_PATH` (clang-unwrapped 22, RISCV and NVPTX
  targets) and `RISCV_TOOLCHAIN_INSTALL_PATH` in the full shell, and
  `nix/patches/sst-elements/vanadis-set-tid-address.patch`.
- 9390328: `balar-cuda12.patch` also links `balar_cuda12_compat.h` into the
  test's temporary libcudart directory.
- c2e16e3: `Justfile` uses `set positional-arguments` and `"$@"`, because
  `{{ args }}` let the shell glob `-w '*balar*'`.
- d63f9c1: the full shell sources gpu-app-collection's `src/setup_environment
  sst`, with `NVIDIA_COMPUTE_SDK_LOCATION` at an empty store directory so
  that the script does not download the CUDA 4.2 SDK.
- 3dda552: input `nixpkgs-cuda11` (nixos-25.05) for
  `balar-gpu-apps-cuda` (CUDA 11.8); the hook adds
  `cuda-install=<CUDA 11.8>` to `MAKE_ARGS`.
- dad4582: `gpu-app-collection-data` (fetchurl of the app data); the hook
  extracts it into the checkout, through a temporary directory.
- 3d240fa: `nix/patches/gpgpu-sim/sst-no-memory-channels.patch`.
- 80dc56f: `nix/patches/sst-elements/vanadis-hwprobe-enosys.patch`.
- 38b0562, 5d22a11: `passthru.runtimeEnv` in `nix/gpgpu-sim.nix`
  (`CUDA_VERSION_NUMBER`, and for CUDA ≥ 6 `PTX_SIM_USE_PTX_FILE`,
  `PTX_SIM_KERNELFILE`, `CUOBJDUMP_SIM_FILE`), merged into the full shell's
  environment.

Uncommitted, in the sst-elements fork:

- `vanadis/os/syscall/settidaddress.h`: return the caller's TID.
- `vanadis/os/vriscvcpuos.h`: `riscv_hwprobe` returns `-ENOSYS`.
- `balar/tests/testBalar_testsuite_util.py`: decorators apply `skipIf`
  directly (the old wrapper hid the test name and ran the test at once);
  `balar_clang_unittest`; the libcudart and Vanadis builds only with both
  toolchain variables; `vectorAdd` became `balar_trace`;
  `SST_CUSTOM_CUDA_LIB_PATH` points to the libcudart directory, not
  `vanadis_llvm_rv64/` (bug since upstream 478baf6e2).
- `balar/tests/testsuite_default_balar.py`: `balar_clang_unittest`.
- `balar/tests/vanadis_llvm_rv64/Makefile`: `--cuda-include-ptx=all`.

## Outcome

`just test elements -w '*balar*'` passes in the full shell.  Earlier in the
session 313 element tests passed and only rdmaNic and balar failed; the
rdmaNic fix and the hwprobe change have not been tested yet.

The failures, in order, and their causes:

| Failure                                       | Cause                                                        |
| --------------------------------------------- | ------------------------------------------------------------ |
| Pin pintool does not compile                  | GCC 15+ warning on anonymous typedef structs, with `-Werror` |
| balar `textureReference`                      | CUDA 12; the patch reached only Nix builds, not `build.sh`   |
| test engine assertion                         | balar decorators renamed the test method to `wrapper`        |
| most elements fail to load                    | stale `libmemHierarchy.so` linked to Ramulator 1             |
| PEBIL `libaddressstream.so`                   | no `LD_LIBRARY_PATH` for instrumented programs               |
| rdmaNic `ebreak` in musl `exit()`             | Vanadis `set_tid_address` returned 0; musl 1.2.6 exit lock   |
| balar libcudart                               | no `RISCV_TOOLCHAIN_INSTALL_PATH` / `LLVM_INSTALL_PATH`      |
| "No TestSuites found"                         | `just` globbed `*balar*`                                     |
| rodinia C23 errors                            | gpu-app-collection on `dev`, not `sst_support`               |
| rodinia link                                  | wrong `SST_CUSTOM_CUDA_LIB_PATH` in the test                 |
| kmeans `texture<>`                            | CUDA 12; apps now use CUDA 11.8                              |
| data step killed (-9)                         | test time limit during the download and `tar`                |
| SIGFPE in GPGPU-Sim                           | `-gpgpu_n_mem 0` and the new IPOLY-MODULO code (e10018b6)    |
| SIGFPE again                                  | stale `libbalar.so` linked to the old GPGPU-Sim              |
| Vanadis DECODE_FAULT in `__strrchr_vector`    | `riscv_hwprobe` success without values; glibc picked RVV     |
| "Cannot detect the app's CUDA version"        | `CUDA_VERSION_NUMBER` not set                                |
| `cuobjdump`: no PTX                           | Clang 22 puts only the cubin into the fat binary             |
| SIGABRT in `pruneSectionList`                 | `CUOBJDUMP_SIM_FILE` not set (GPGPU-Sim `setup_environment`) |

Rejected or wrong:

- **rv64g toolchain (25a9079):** the theory was that Vanadis cannot decode
  compressed (RVC) instructions.  It can
  (`vanadis/decoder/vriscv64decoder.h:2598`), and balar's Makefiles use
  `rv64gc`.  Reverted.  The real rdmaNic cause was `set_tid_address`.
- **CUDA 11 for everything:** asked mid-session.  Only the two texture
  failures came from CUDA 12.  CUDA 11.8's nvcc needs GCC ≤ 11, so
  GPGPU-Sim, balar and vectorAdd would need an old GCC and glibc from an
  unsupported nixpkgs.  Kept CUDA 12.9 and used 11.8 only for the apps.
- **Port kmeans to texture objects:** balar's libcudart handles only
  texture references (`cudaBindTexture`, `__cudaRegisterTexture`).
- **Link `data_dirs/` to the store:** some apps write into their `data/`
  (heartwall `result-1.txt`), so the hook extracts a writable copy.
- **Pin GPGPU-Sim to 03c1fe44** (before the Hopper commit): kept 91880c5
  with the small patch instead; the user can still choose the pin.

Notes for later sessions:

- The sandbox has no coreutils, git, nix, just, python or jq on PATH, but
  `/nix/store` binaries run; find them with a glob such as
  `/nix/store/*-coreutils-9.11/bin/cat`.  A glob that matches several store
  paths gives several arguments; take `"${arr[0]}"`.
- `common.mk` of gpu-app-collection and GPGPU-Sim print with buffered
  stdout, so an abort loses the last messages; read the source near the
  crash.
- The balar test captures only stdout; run the make by hand for errors.
- Each test run deletes `build/test-elements/sst_test_outputs/` first.
- GPGPU-Sim's `setup_environment` warns for CUDA above 12.8; 12.9 has
  worked so far.

## Follow-ups

- Run `just test elements -w '*vanadis*'` and `-w '*rdmaNic*'` for the two
  Vanadis syscall changes.
- `prek run --files` in sst-elements for the changed files; commit the fork
  changes (the Vanadis patch headers have the messages).
- `nix flake check`.
- The rodinia apps need `--cuda-include-ptx=all` in gpu-app-collection's
  `src/cuda/common/common.mk` before the rodinia tests are enabled.
- Proposal: twice a library stayed linked to an old store path after only a
  dependency changed (`libmemHierarchy`, `libbalar`).  `clean_if_patched`
  covers new patches, not new dependency paths.  `build.sh` could store the
  configure arguments in the build tree and remove the tree when they
  change.
- Repeated commands: no new recipe.  The user's commands were already
  recipes (`just test`, `just build-elements-full`); the commands repeated
  on the agent side were sandbox lookups of store binaries.
