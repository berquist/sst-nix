# Intel Pin: dynamic binary instrumentation, the default frontend of the
# Ariel element of sst-elements (and the trace tool of prospero).  Not in
# nixpkgs.  Binary distribution, unfree.
#
# The version is the pin/pin-3.31 module that sst-sqe's bamboo.sh loads.
# configure of sst-elements wants the kit itself (pin, source/include,
# intel64/runtime), so $out is the unpacked kit.
{
  lib,
  stdenv,
  fetchurl,
  patchelf,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "intel-pin";
  version = "3.31";
  build = "98869-gfa6f126a8";

  src = fetchurl {
    url = "https://software.intel.com/sites/landingpage/pintool/downloads/pin-external-${finalAttrs.version}-${finalAttrs.build}-gcc-linux.tar.gz";
    hash = "sha256-giFhROPfdo8CA7Zx/0hgUxTxMmaQPrQtrAG5ExDrqVY=";
  };

  nativeBuildInputs = [ patchelf ];

  dontConfigure = true;
  dontBuild = true;
  # Pin checks its own binaries; leave them as shipped apart from the
  # interpreter below.
  dontStrip = true;
  dontPatchELF = true;

  # pinbin and pindb ask for /lib64/ld-linux-x86-64.so.2; their libraries
  # (the Pin C runtime) are found by the pin launcher.  The ia32 binaries
  # are for 32-bit programs and keep their interpreter.
  installPhase = ''
    runHook preInstall
    mkdir --parents $out
    cp --recursive . $out/
    for program in $out/intel64/bin/pinbin $out/intel64/bin/pindb; do
      patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" "$program"
    done
    # A typo in a header: the member is _base.  GCC 15 and later reject it
    # even in this uninstantiated template, which the Ariel pintool includes.
    substituteInPlace $out/extras/components/include/util/range.hpp \
      --replace-fail "Contains(range.m_base)" "Contains(range._base)"
    # Three anonymous structs with member functions get their linkage name
    # from a typedef, which GCC 15 and later warn about
    # (-Wnon-c-typedef-for-linkage), and the pintool is compiled with -Werror.
    # Give each struct the name of its typedef; the mangled names stay the same.
    substituteInPlace $out/source/include/pin/gen/pinsync.hpp \
      --replace-fail $'non-recursive lock with POD semantics.\n */\ntypedef struct\n' \
                     $'non-recursive lock with POD semantics.\n */\ntypedef struct PINSYNC_POD_LOCK\n' \
      --replace-fail $'Read-writer lock with POD semantics.\n */\ntypedef struct\n' \
                     $'Read-writer lock with POD semantics.\n */\ntypedef struct PINSYNC_POD_RWLOCK\n' \
      --replace-fail $'works as a barrier.\n */\ntypedef struct\n' \
                     $'works as a barrier.\n */\ntypedef struct PINSYNC_POD_SEMAPHORE\n'
    mkdir --parents $out/bin
    ln --symbolic $out/pin $out/bin/pin
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    $out/pin -version
    $out/pin -- ${stdenv.shell} -c true
    runHook postInstallCheck
  '';

  meta = {
    description = "Dynamic binary instrumentation framework";
    homepage = "https://www.intel.com/content/www/us/en/developer/articles/tool/pin-a-dynamic-binary-instrumentation-tool.html";
    license = {
      fullName = "Intel Simplified Software License";
      url = "https://www.intel.com/content/www/us/en/developer/articles/license/simplified-software-license.html";
      free = false;
      redistributable = true;
    };
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "pin";
    platforms = [ "x86_64-linux" ];
  };
})
