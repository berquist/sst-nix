---
date: 2026-11-01
slug: per-test-dir-names
status: partial
sessions: ["fd6a1885-260d-4c39-9b3b-f748d6ab32eb"]
touches:
  - "sst-core/src/sst/core/testingframework/sst_unittest.py"
  - "sst-elements/src/sst/elements/ember/tests/testsuite_default_ember_*.py"
  - "sst-elements/src/sst/elements/prospero/tests/testsuite_default_prospero.py"
  - "sst-elements/src/sst/elements/zodiac/test/testsuite_default_SiriusZodiacTrace.py"
---

# Per-test directory names without `_testMethodName`

Follows [2026-10-29 concurrent element tests](2026-10-29-concurrent-element-tests.md),
which added the per-test folders that this session renames.

## Ask

1. "Look at the current (unstaged) work in sst-elements to have
   test-specific directories in order to avoid race conditions.  They're all
   using self._testMethodName.  Is there a normal Python unittest way of
   doing this, or at least one that doesn't rely on a private member?  Even
   better would be moving this functionality, which seems common, to a set up
   method."
2. Answer to "Where should that part go?": "Both, staged".
3. "write the worklog, but to sst-nix, not elements or core"

## Plan

### Context

The unstaged sst-elements work gives each test its own directory under the
shared tmp dir, so concurrent tests (`-c N`) do not race on one folder.  Seven
suites build the path with `self._testMethodName`, which is an undocumented
private attribute of `unittest.TestCase`.

Findings:

- Plain unittest has no public "method name" accessor.  The documented API is
  `self.id()`, which returns `module.Class.method`.  Using it as a directory
  name works, but it is long and not what these lines want.
- `SSTTestCase.__init__` already stores the method name as a public attribute:
  `self.testname = methodName`
  (`sst-core/src/sst/core/testingframework/sst_unittest.py:57`).  For
  `parameterized.expand` tests (ember sweep) this is the expanded, unique name.
  This is the SST-native answer.
- The directories are already made in `setUp()`: each suite's `setUp` calls its
  own `_setupXxx()` helper.  The part that repeats in every suite is "rmtree
  then makedirs `<tmpdir>/<label>/<testname>`".  Only the label and what is
  linked into the directory differ.

User decision: do both, staged.  Stage 1 needs no sst-core change.  Stage 2
adds a shared helper to sst-core and is a separate upstream change.

### Stage 1 — sst-elements: use `self.testname`

Replace `self._testMethodName` with `self.testname` in these lines (same
`.format(tmpdir, ...)` style, nothing else changes):

- `src/sst/elements/ember/tests/testsuite_default_ember_ESshmem.py:193`
- `src/sst/elements/ember/tests/testsuite_default_ember_nightly.py:79`
- `src/sst/elements/ember/tests/testsuite_default_ember_otf2.py:70`
- `src/sst/elements/ember/tests/testsuite_default_ember_qos.py:115`
- `src/sst/elements/ember/tests/testsuite_default_ember_sweep.py:251`
- `src/sst/elements/prospero/tests/testsuite_default_prospero.py:171-172`
- `src/sst/elements/zodiac/test/testsuite_default_SiriusZodiacTrace.py:97`

Keep the rest of the unstaged sst-elements work (Ariel, balar, rdmaNic, C++)
as it is.

### Stage 2 — sst-core: helper on `SSTTestCase` (follow-up)

In `sst-core/src/sst/core/testingframework/sst_unittest.py`, next to
`get_test_output_tmp_dir()` (line 201), add a method in the same docstring
style:

```python
def make_test_tmp_dir(self, name: str) -> str:
    """ Create a clean tmp directory that only this test uses
    ...
    Args:
        name (str): Name of the directory; the test name is added below it
    Returns:
        (str) The path to <tmp dir>/<name>/<test name>
    """
    path = os.path.join(self.get_test_output_tmp_dir(), name, self.testname)
    shutil.rmtree(path, ignore_errors=True)
    os.makedirs(path)
    return path
```

(The `...` marks an elided docstring body.  Check `shutil` is imported there;
add it if not.)  Callers do this in their `setUp()` path, as now.

Then, as a later sst-elements change that needs the new sst-core, each
`_setupXxx()` replaces its own path + `isdir`/`rmtree`/`makedirs` block with
one call, for example in the ember sweep suite:

```python
self.emberSweep_Folder = self.make_test_tmp_dir("embersweep_folder")
```

Same pattern for the other ember suites, prospero (two calls) and zodiac.

### Verification

Stage 1 (from the sst-nix root, after `just build elements` if needed):

- `just test elements -c 8 -w "*ember*"` and
  `just test elements -c 8 -w "*prospero*"` and
  `just test elements -c 8 -w "*SiriusZodiacTrace*"`: all pass or skip as
  before.
- Check that the tmp dir holds one subdirectory per test, named by test, for
  example `build/test-elements/sst_test_outputs/tmp_data/embersweep_folder/`.

Stage 2:

- `just build core`, then `just test core` (framework still works).
- Rebuild elements, rerun the three concurrent runs above.
- `prek run --files <changed files>` in each repo if it has a pre-commit
  config.

## Out-of-band

None.

## Changes

- sst-elements, 7 suites (unstaged, uncommitted): 8 lines changed from
  `self._testMethodName` to `self.testname`.  These lines are part of the
  unstaged per-test folder work from 2026-10-29; the rest of that work was not
  touched.

## Outcome

- Stage 1 done.  `rg` confirms no `_testMethodName` is left in those suites,
  and the diff kept every file's trailing newline.
- Not tested.  The sandbox had only `bash` on PATH (no `just`, `sst`,
  Python, `git` or `rg`; `git`, `rg` and `jq` were run from `/nix/store`
  paths).  The concurrent test runs in Verification are still to do.
- Rejected: `self.id()`.  It is the documented unittest API, but it gives
  `module.Class.method`, which is long, and the suite folder name already
  identifies the class.
- Stage 2 not started; waiting for the user.

## Follow-ups

- Run the three `just test elements -c 8 -w ...` runs for stage 1.
- Stage 2: add `SSTTestCase.make_test_tmp_dir(name)` to sst-core, then switch
  the seven `_setupXxx()` helpers to it once sst-elements can require that
  sst-core.
- No command recurred three times in this session; nothing to make
  permanent.
