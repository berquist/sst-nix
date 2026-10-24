# sst-hgcc: Clang libTooling source-to-source compiler (hgcc, hg++) that
# turns application code into element libraries for the mercury element of
# sst-elements.  Not in nixpkgs.
#
# configure wants one LLVM root with bin/clang, bin/llvm-config,
# include/clang and lib/libclang-cpp; nixpkgs splits these over several
# packages, so llvmRoot joins them.  `make install` puts the test and
# example libraries in the SST_ELEMENT_LIBRARY_EXT_LIBDIR of sst-elements,
# which is read-only here; they go to $out/lib/sst-hgcc/ext instead, which
# $out/etc/sst/sst-hgcc.conf registers.
{
  lib,
  stdenv,
  src,
  version,
  symlinkJoin,
  makeWrapper,
  autoconf,
  automake,
  libtool,
  python3,
  lit,
  procps,
  coreutils,
  gnugrep,
  binutils,
  llvmPackages,
  sst-core,
  sst-elements,
}:

let
  llvmRoot = symlinkJoin {
    name = "llvm-root-${llvmPackages.llvm.version}";
    # The wrapped clang first: libclang also has an unwrapped bin/clang++,
    # which knows no libstdc++ headers, and the first path wins.
    paths = with llvmPackages; [
      clang
      llvm
      llvm.dev
      llvm.lib
      libclang
      libclang.dev
      libclang.lib
    ];
  };
  extLibDir = "${placeholder "out"}/lib/sst-hgcc/ext";
in
stdenv.mkDerivation {
  pname = "sst-hgcc";
  inherit src version;

  nativeBuildInputs = [
    autoconf
    automake
    libtool
    python3
    lit
    makeWrapper
    procps # hgcc runs ps, also in the lit tests
    llvmPackages.llvm # FileCheck
    sst-core
    sst-elements
  ];

  buildInputs = [
    sst-core
    sst-elements
    llvmPackages.libclang
    llvmPackages.llvm
  ];

  postPatch = ''
    patchShebangs autogen.sh config_tools tests
  '';

  preConfigure = ''
    ./autogen.sh
  '';

  configureFlags = [
    "--with-sst-core=${sst-core}"
    "--with-sst-elements=${sst-elements}"
    "--with-clang=${llvmRoot}"
    "--with-std=17"
    "--enable-strict-tests"
  ];

  enableParallelBuilding = true;

  # lit tests of the rewriter, and the test_tls element library.
  doCheck = true;
  preCheck = ''
    export HOME="$TMPDIR"
  '';

  installFlags = [ "SST_ELEMENT_LIBRARY_EXT_LIBDIR=${extLibDir}" ];

  # hgcc and hg++ walk their process tree with ps, and run nm, grep, rm and
  # chmod.
  postInstall = ''
    for program in hgcc hg++; do
      wrapProgram $out/bin/$program \
        --prefix PATH : ${
          lib.makeBinPath [
            procps
            coreutils
            gnugrep
            binutils
          ]
        }
    done
    mkdir --parents $out/etc/sst
    cat > $out/etc/sst/sst-hgcc.conf <<EOF
    [sst-hgcc]
    SST_HGCC_EXT_LIBDIR=${extLibDir}
    EOF
  '';

  setupHook = ./sst-element-setup-hook.sh;

  # test_tls and the examples, run in sst from $out.  The setup hook of
  # sst-elements has put its conf on SST_CONFIG_FILE_PATH already.
  doInstallCheck = true;
  installCheckFlags = [ "SST_ELEMENT_LIBRARY_EXT_LIBDIR=${extLibDir}" ];
  preInstallCheck = ''
    export HOME="$TMPDIR"
    export SST_CONFIG_FILE_PATH="$out/etc/sst/sst-hgcc.conf:$SST_CONFIG_FILE_PATH"
    export PATH="$out/bin:$PATH"
  '';

  passthru = {
    sstConf = "etc/sst/sst-hgcc.conf";
    inherit llvmRoot;
  };

  meta = {
    description = "Clang-based compiler that turns applications into SST mercury element libraries";
    homepage = "https://github.com/sstsimulator/sst-hgcc";
    license = lib.licenses.bsd3;
    mainProgram = "hgcc";
    platforms = lib.platforms.unix;
  };
}
