# Open Trace Format (OTF) version 1, trace library of VampirTrace.  Used by
# the zodiac element of sst-elements.  Not in nixpkgs.
#
# The download site of TU Dresden is down; the Spack source cache keeps the
# tarball (spack package "otf").
{
  lib,
  stdenv,
  fetchurl,
  zlib,
  mpi,
  python3,
  swig,
  mpiSupport ? true,
  # SWIG bindings, module `otf`
  pythonSupport ? true,
}:

stdenv.mkDerivation {
  pname = "otf";
  version = "1.12.5";

  src = fetchurl {
    urls = [
      "https://wwwpub.zih.tu-dresden.de/%7Emlieber/dcount/dcount.php?package=otf&get=OTF-1.12.5salmon.tar.gz"
      "https://mirror.spack.io/_source-cache/archive/0a/0a8427360dedb38e8ddca30f14d95f826420c550337c5a79dbb754904e194088.tar.gz"
    ];
    name = "OTF-1.12.5salmon.tar.gz";
    hash = "sha256-CoQnNg3ts46N3KMPFNlfgmQgxVAzfFp527dUkE4ZQIg=";
  };

  # Python 3.13 removed PyEval_CallObject; PyObject_CallObject is the same.
  # SWIG 4.3 added an is_void argument to SWIG_Python_AppendOutput.
  # __init__.py has a Python 2 implicit relative import.
  postPatch = lib.optionalString pythonSupport ''
    substituteInPlace otflib_py/__init__.py \
      --replace-fail "from otf import *" "from .otf import *"
    substituteInPlace otflib_py/pyOTF_Wrapper.h \
      --replace-fail PyEval_CallObject PyObject_CallObject \
      --replace-fail SWIG_Python_AppendOutput OTF_SWIG_APPEND
    sed --in-place '1i #if SWIG_VERSION >= 0x040300\
    #define OTF_SWIG_APPEND(result, obj) SWIG_Python_AppendOutput(result, obj, 0)\
    #else\
    #define OTF_SWIG_APPEND(result, obj) SWIG_Python_AppendOutput(result, obj)\
    #endif' otflib_py/pyOTF_Wrapper.h
  '';

  nativeBuildInputs =
    lib.optional mpiSupport mpi
    ++ lib.optionals pythonSupport [
      python3
      swig
    ];

  buildInputs = [ zlib ] ++ lib.optional mpiSupport mpi ++ lib.optional pythonSupport python3;

  configureFlags = [
    "--with-zlib"
    "--with-zlib-dir=${lib.getDev zlib}"
    "--with-zlib-lib-dir=${lib.getLib zlib}/lib"
    (lib.withFeature mpiSupport "mpi")
    (lib.enableFeature pythonSupport "python-bindings")
    # Not packaged anywhere: the VTF3 converter and ZOIDFS I/O forwarding.
    "--without-vtf3"
    "--without-zoidfs"
  ]
  ++ lib.optionals mpiSupport [
    "--with-mpi-dir=${lib.getDev mpi}"
    "--with-mpi-lib-dir=${lib.getLib mpi}/lib"
  ]
  ++ lib.optionals pythonSupport [
    "PYTHON_VERSION=${python3.pythonVersion}"
    # The AM_PATH_PYTHON of the tarball takes sys.version[:3], "3.1".
    "am_cv_python_pythondir=${placeholder "out"}/${python3.sitePackages}"
    "am_cv_python_pyexecdir=${placeholder "out"}/${python3.sitePackages}"
  ];

  enableParallelBuilding = true;

  # `make check` only builds the test programs (check_PROGRAMS).
  doCheck = true;

  # otf_hello writes a trace that otfinfo reads; the Python tests write and
  # read one through the bindings.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    (cd tests/hello && ./otf_hello)
    $out/bin/otfinfo tests/hello/hello_world.otf
  ''
  + lib.optionalString pythonSupport ''
    export PYTHONPATH="$out/${python3.sitePackages}''${PYTHONPATH:+:$PYTHONPATH}"
    python3 tests/python/python3/test_write.py written.otf
    python3 tests/python/python3/test_read.py written.otf > /dev/null
  ''
  + ''
    runHook postInstallCheck
  '';

  meta = {
    description = "Open Trace Format, the trace library of VampirTrace";
    homepage = "https://tu-dresden.de/zih/forschung/projekte/otf";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.unix;
  };
}
