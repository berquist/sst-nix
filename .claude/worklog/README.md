# Worklog

- [2026-11-01 per-test dir names](2026-11-01-per-test-dir-names.md) — SSTTestCase.testname is the public method name; suites switched from _testMethodName; make_test_tmp_dir() helper in sst-core still to do.
- [2026-10-29 concurrent element tests](2026-10-29-concurrent-element-tests.md) — threads share os.environ and tmp dirs; run_sst(env=), per-test folders, Ariel build lock; remaining Vanadis gold mismatches also fail serially.
- [2026-10-28 balar and Vanadis tests](2026-10-28-balar-vanadis-tests.md) — 18 failures to a passing balar test; rv64g theory was wrong, CUDA 11 only for gpu apps, GPGPU-Sim needs its setup_environment variables.
- [2026-10-16 sst-nix flake](2026-10-16-sst-nix-flake.md) — the whole flake; why each patch exists, the libramulator.so clash, and that sst-info exits 0 on load failures.
