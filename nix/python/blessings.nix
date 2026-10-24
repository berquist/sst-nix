# Terminal colouring for the SST test framework (sst-test-core).  Not in
# nixpkgs.
{
  lib,
  buildPythonPackage,
  fetchPypi,
  setuptools,
  six,
  pytest,
  util-linux,
}:

buildPythonPackage rec {
  pname = "blessings";
  version = "1.7";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-mOWFTYBfUKW1isIzNBGwSCUWqCEPI/QzCLrrWNd8FX0=";
  };

  # The tests use nose, which is not in nixpkgs; these are the two names they
  # take from it.
  postPatch = ''
    substituteInPlace blessings/tests.py \
      --replace-fail "from nose import SkipTest" "from unittest import SkipTest" \
      --replace-fail "from nose.tools import eq_" "def eq_(a, b): assert a == b, (a, b)"
  '';

  build-system = [ setuptools ];

  dependencies = [ six ];

  nativeCheckInputs = [
    pytest
    util-linux
  ];

  # Some tests assume that stdout is a terminal of a type with a terminfo
  # entry, so `script` runs them on a pseudo-terminal, and -s keeps pytest
  # from capturing that terminal.
  checkPhase = ''
    runHook preCheck
    export TERM=xterm-256color
    script --quiet --return --command "python -m pytest -s -p no:cacheprovider blessings/tests.py" /dev/null
    runHook postCheck
  '';

  pythonImportsCheck = [ "blessings" ];

  meta = {
    description = "Thin, practical wrapper around terminal coloring, styling, and positioning";
    homepage = "https://github.com/erikrose/blessings";
    license = lib.licenses.mit;
  };
}
