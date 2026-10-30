---
date: 2026-10-29
slug: concurrent-element-tests
status: partial
sessions: ["a31941bc-fc10-43c8-b02e-66f9eedb5e3e"]
touches:
  - "sst-core/src/sst/core/testingframework/sst_unittest.py"
  - "sst-elements/src/sst/elements/*/tests/testsuite_*.py"
  - "sst-elements/src/sst/elements/zodiac/test/testsuite_*.py"
  - "sst-elements/src/sst/elements/memHierarchy/tests/testsuite_*_memHierarchy_*.py"
---

# Concurrent element tests (`sst-test-elements -c 64`)

## Ask

The user's own words, in order.  Long pasted failure logs are replaced by a
note in brackets.

1. "Concurrent testing isn't working.  I think there are multiple reasons
   why.  Here are some initial failures:" [Ember ESshmem `FileExistsError`
   tracebacks]
2. "remaining failing Ember tests:" [Ember Nightly and QOS failures]
3. "fix the otf2 test too"
4. "Here is the run of the entire test suite with 64 threads.  All of these
   failures except Balar, which you can skip, should be due to test framework
   concurrency problems." [Prospero, Zodiac, Ariel, Golem, Vanadis, rdmaNic
   and Balar failures]
5. [Paste only: `just test elements -k test_vanadis_short_tests_003` failed
   with "unrecognized arguments"]
6. "it passes"
7. "I think this is the same thing as
   https://github.com/sstsimulator/sst-core/issues/1129.  I approve of the
   patch.  I approve of the current Ariel library order."
8. "I don't think this is complete; does os_command.run actually use the env
   kwarg?"
9. "Progress:" [rdmaNic `msg` and 22 Vanadis multi-core/multi-thread gold-file
   mismatches]
10. "Why can't you just take the diffs yourself?"
11. "it doesn't pass"
12. `/worklog`

## Plan

No plan mode.  The cause: concurrent mode runs every test as a thread in one
Python process (`test_engine_unittest.py`, `threading.Thread(target=
self._run_test)`).  So the cwd, `os.environ` and shared tmp folders are shared
by all running tests.  Three fixes:

1. **A folder for each test:** `"{0}/<name>/{1}".format(tmpdir,
   self._testMethodName)`.
2. **An environment for each test:** a new `env=` argument on
   `SSTTestCase.run_sst`, merged over `os.environ` and given to `Popen`.  The
   user reviewed it as `.scratch/per-test-env.diff` (patch-review skill) and
   approved it.
3. **A file lock around a shared build:** `fcntl.flock` on
   `tmp_data/ariel_build.lock`.  On Linux, each `open()` gets its own lock, so
   the lock also works between threads.

## Out-of-band

The user ran these in their own terminal.  Only the results they reported are
known.

- `just test elements -k test_vanadis_short_tests_003`: fails, because `-k`
  means "keep output".  The correct form is `just test elements -z -w
  "*vanadis*" -e <test name>`.
- `test_vanadis_short_tests_003_small_basic_io_hello_world_riscv64_`
  serially: passes.
- Full suite with `-c 64` after the patch: only rdmaNic `msg` and Vanadis
  multi-core or multi-thread tests fail (gold-file mismatches).
- `test_vanadis_short_tests_049_small_misc_pthread_riscv64_gold2` serially:
  fails, with the same output as in the concurrent run.

## Changes

Nothing is committed or staged.  The sandbox has no `git`.

sst-core:

- `sst_unittest.py`: `run_sst(..., env=None)`.  The values go on top of
  `os.environ` and pass through `os_command.run(**kwargs)` to `Popen`.

sst-elements, a folder for each test:

- `ember/tests/testsuite_default_ember_{ESshmem,sweep,nightly,qos,otf2}.py`
- `prospero/tests/testsuite_default_prospero.py`
- `zodiac/test/testsuite_default_SiriusZodiacTrace.py`

sst-elements, `env=` instead of writes to `os.environ`:

- `golem/tests/testsuite_default_golem.py`
- `rdmaNic/tests/testsuite_default_rdmaNic.py`: also runs in its own
  `outdir`, with links to the `.py` files and `msglen.txt`.  Before, it wrote
  `std{out,err}-{0,1}-100` into the source tree.
- `ariel/tests/testsuite_default_Ariel.py`: also the build lock.
  `LD_LIBRARY_PATH` is built for each test, with the test libdir before the
  existing value.
- `ariel/tests/testsuite_testio_Ariel.py`
- `mask-mpi/tests/testsuite_default_mask_mpi.py`: removed a context manager
  that changed `os.environ` for the duration of a test.
- Nine memHierarchy suites, for `OMP_EXE`:
  `testsuite_openMP_memHierarchy_{dirnoncacheable,diropenMP,noncacheable,openMP}.py`
  and
  `testsuite_sweep_memHierarchy_{dir3LevelSweep,dirSweep,dirSweepB,dirSweepI,openMP}.py`.
  A bash script did these edits and rewrote each file with `printf '%s\n'`,
  so check the final newline in the diff.

## Outcome

- The folder races, the Ariel build race and the environment races are fixed.
  After the change, none of these failures came back in the `-c 64` run.
- The remaining failures are not about concurrency.  The output of the
  `pthread riscv64 gold2` test is the same serially and concurrently (end time
  218.251 us, gold 214.436 us).  Only the statistics and the end time differ;
  the guest output is correct.  The Vanadis OS clock uses simulated time only
  (`vanadis/os/vnodeos.h:190`), so host load cannot change it through that
  path.
- Wrong theory: the first Vanadis failures (before the patch) were first
  thought to be unrelated to concurrency.  The real cause was rdmaNic IMB's
  `VANADIS_EXE_ARGS` in the shared `os.environ`, which leaked into Vanadis
  runs.
- Replaced: an early rdmaNic fix used `os.environ.pop` after each run.  This
  still had a race, and `env=` replaced it.
- Not changed: `ariel/tests/testsuite_mpi_Ariel.py:287` writes
  `os.environ["ARIELAPI"]`.  It always writes the same value, so it cannot
  give a test a wrong value.  The Balar util also writes `os.environ`
  (skipped, as the user asked).

## Follow-ups

- Find why the Vanadis multi-core/multi-thread and rdmaNic `msg` gold files
  do not match.  Run one test on a checkout without `80dc56f` ("Vanadis
  RISC-V fix"), or on upstream `master`.  The mipsel failures make that
  commit an incomplete explanation.
- `rm -rf .scratch`.  The sandbox has no `rm`.
- Delete `sst-elements/src/sst/elements/rdmaNic/tests/{stdout,stderr}-{0,1}-100`
  unless git tracks them.
- Run `prek` on the changed files if a pre-commit config exists, then stage
  and commit sst-core and sst-elements separately.
- Proposal: the sandbox lacks coreutils, `git`, `diff` and Python.  This
  session used bash builtins for every search and comparison.  Forwarding
  those tools into the sandbox would make this kind of work faster.
- No new `just` recipe is needed: `just test elements -z -w <suite> -e
  <test>` already covers the repeated test runs.
