# SST elements: the component libraries (memHierarchy, merlin, ariel,
# vanadis, ...) that sst-core loads.  Not in nixpkgs.
#
# Every third-party dependency is optional and off by default, as upstream.
# configure detects some of them on its own, so each one is passed as
# --with-X=PATH or --without-X.
#
# `make install` registers the libraries with sst-register.  It cannot write
# the sstsimulator.conf of sst-core in the store, so it writes one in a
# temporary HOME, and the result is split in two fragments:
#   $out/etc/sst/<pname>.conf    library paths; the setup hook adds it to
#                                SST_CONFIG_FILE_PATH
#   $testsuite/etc/sst/<pname>.conf  test suite and source paths, for
#                                sst-test-elements (see sst-with-elements.nix)
{
  lib,
  stdenv,
  src,
  version,
  pname ? "sst-elements",
  autoconf,
  automake,
  libtool,
  gawk,
  sst-core,
  zlib,

  # Python packages that element scripts and the Python models import:
  # numpy, sympy, networkx and matplotlib (ember, merlin, golem), galois
  # (merlin Slimfly topology).  NumPy also enables golem's CrossSim array.
  pythonSupport ? false,

  # Third-party simulators and tools, one configure check each.  The
  # packages are only used when their flag is set.
  otf2Support ? false, # ember: OTF2 trace motifs
  otf2 ? null,
  otfSupport ? false, # zodiac: OTF v1 traces
  otf ? null,
  dumpiSupport ? false, # zodiac: DUMPI traces (does not build, see overlay.nix)
  sst-dumpi ? null,
  ramulatorSupport ? false, # memHierarchy: Ramulator backend
  ramulator ? null,
  ramulator2Support ? false, # memHierarchy: Ramulator 2 backend
  ramulator2 ? null,
  goblinHmcsimSupport ? false, # memHierarchy: HMC backend
  goblin-hmcsim ? null,
  stakeSupport ? false, # miranda: Stake (RISC-V Spike) generator
  spike ? null,
  pinSupport ? false, # ariel and prospero: Pin frontend (x86_64, unfree)
  intel-pin ? null,
  cudaSupport ? false, # balar: GPGPU-Sim with CUDA
  cudaPackages ? null,
  gpgpu-sim ? null,
}:

let
  opt = flag: pkg: if flag then pkg else null;
  deps = {
    otf2 = opt otf2Support otf2;
    otf = opt otfSupport otf;
    sst-dumpi = opt dumpiSupport sst-dumpi;
    ramulator = opt ramulatorSupport ramulator;
    ramulator2 = opt ramulator2Support ramulator2;
    goblin-hmcsim = opt goblinHmcsimSupport goblin-hmcsim;
    spike = opt stakeSupport spike;
    intel-pin = opt pinSupport intel-pin;
    cuda = opt cudaSupport cudaPackages.cudatoolkit;
    gpgpu-sim = opt cudaSupport gpgpu-sim;
  };

  python = sst-core.python;
  pythonDeps =
    ps: with ps; [
      numpy
      sympy
      networkx
      matplotlib
      galois
    ];
  pythonPath = python.withPackages pythonDeps;
  numpyInclude = "${python.pkgs.numpy}/${python.sitePackages}/numpy/_core/include";

  # --with-<name>=<prefix of deps.<dep>>, or --without-<name>.  Packages whose
  # layout differs from what configure expects provide passthru.sstPrefix.
  withOrWithout =
    name: dep:
    if deps.${dep} == null then
      "--without-${name}"
    else
      "--with-${name}=${deps.${dep}.sstPrefix or (lib.getDev deps.${dep})}";

  sstConfigureFlags = [
    "--with-libz=${lib.getDev zlib}"
    (withOrWithout "otf2" "otf2")
    (withOrWithout "otf" "otf")
    (withOrWithout "dumpi" "sst-dumpi")
    (withOrWithout "ramulator" "ramulator")
    (withOrWithout "ramulator2" "ramulator2")
    (withOrWithout "goblin-hmcsim" "goblin-hmcsim")
    (withOrWithout "stake" "spike")
    (withOrWithout "pin" "intel-pin")
  ]
  # The CUDA and GPGPU-Sim checks take "no" as a directory, so these are
  # left out when off; configure then finds no cuda.h and disables balar.
  ++ lib.optionals cudaSupport [
    (withOrWithout "cuda" "cuda")
    (withOrWithout "gpgpusim" "gpgpu-sim")
  ]
  # Without the flag, configure asks the interpreter of sst-core, which has
  # no NumPy.  Do not pass --without-numpy: same problem as above.
  ++ lib.optional pythonSupport "--with-numpy=${numpyInclude}";
in
stdenv.mkDerivation (finalAttrs: {
  inherit pname src version;

  outputs = [
    "out"
    "testsuite"
  ];

  nativeBuildInputs = [
    autoconf
    automake
    libtool
    gawk
    sst-core
  ];

  buildInputs = [
    sst-core
    zlib
  ]
  ++ lib.optional pythonSupport python.pkgs.numpy
  ++ lib.filter (p: p != null) (lib.attrValues deps);

  # Each only where it matters, so that the other variants keep the
  # upstream source.  Vanadis is in every variant.
  patches = [
    ./patches/sst-elements/vanadis-set-tid-address.patch
  ]
  ++ lib.optional ramulator2Support ./patches/sst-elements/ramulator2-lib-name.patch
  ++ lib.optional cudaSupport ./patches/sst-elements/balar-cuda12.patch;

  postPatch = ''
    patchShebangs autogen.sh
  '';

  preConfigure = ''
    ./autogen.sh
  '';

  # The summary at the end of configure uses bash indirection.
  configureFlags = [ "--with-sst-core=${sst-core}" ] ++ sstConfigureFlags;
  CONFIG_SHELL = stdenv.shell;

  enableParallelBuilding = true;

  preInstall = ''
    export HOME="$TMPDIR/home"
    mkdir --parents "$HOME/.sst"
    touch "$HOME/.sst/sstsimulator.conf"
  '';

  # The test suites and the element sources are registered with paths into
  # the build tree; they go to $testsuite from the pristine source, so that no
  # build products come along.  (The output is not named `tests`, which
  # would clash with passthru.tests.)
  postInstall = ''
    mkdir --parents $out/etc/sst $testsuite/etc/sst $testsuite/share/sst-elements/src
    cp --recursive ${finalAttrs.src}/src/sst $testsuite/share/sst-elements/src/sst
    chmod --recursive u+w $testsuite/share/sst-elements
    cp src/sst_element_config.h $testsuite/share/sst-elements/src/

    conf="$HOME/.sst/sstsimulator.conf"
    substituteInPlace "$conf" --replace-quiet "$PWD" "$testsuite/share/sst-elements"
    awk -v out="$out/etc/sst/$pname.conf" -v tests="$testsuite/etc/sst/$pname.conf" '
      /^\[/ { file = ($0 == "[SST_ELEMENT_SOURCE]" || $0 == "[SST_ELEMENT_TESTS]" || $0 == "[rtlcomponent]") ? tests : out }
      file != "" { print > file }
    ' "$conf"
    # sst-test-elements reads the build directory from the library section.
    printf '[SST_ELEMENT_LIBRARY]\nSST_ELEMENT_LIBRARY_BUILDDIR=%s\n' \
      "$testsuite/share/sst-elements" >> "$testsuite/etc/sst/$pname.conf"
    sed --in-place '/SST_ELEMENT_LIBRARY_BUILDDIR=/d; /SST_ELEMENT_LIBRARY_SOURCE_ROOT=/d' \
      "$out/etc/sst/$pname.conf"
  '';

  setupHook = ./sst-element-setup-hook.sh;

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    export HOME="$TMPDIR/check-home"
    mkdir --parents "$HOME"
    export SST_CONFIG_FILE_PATH="$out/etc/sst/$pname.conf"
    # A library that fails to load only shows as "UNABLE TO PROCESS".
    if ldd $out/lib/sst-elements-library/*.so | grep 'not found'; then
      exit 1
    fi
    # sst-info exits 0 even when a library does not load; it only says so.
    # Without arguments it loads every registered library.
    sst-info > sst-info.out 2>&1 || { cat sst-info.out; exit 1; }
    if grep 'UNABLE TO PROCESS' sst-info.out; then
      SST_CORE_DL_VERBOSE=1 sst-info 2>&1 | grep 'undefined symbol' || true
      exit 1
    fi
    runHook postInstallCheck
  '';

  passthru = {
    inherit sst-core sstConfigureFlags pythonDeps;
    # The optional dependencies in use (null when off).
    inherit deps;
    # Run-time Python environment of the element scripts, for wrappers.
    pythonEnv = if pythonSupport then pythonPath else null;
    sstConf = "etc/sst/${pname}.conf";
  };

  meta = {
    description = "Structural Simulation Toolkit element libraries";
    homepage = "https://sst-simulator.org";
    downloadPage = "https://github.com/sstsimulator/sst-elements";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.unix;
  };
})
