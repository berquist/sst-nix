# Lmod: Lua based environment module system.  Not in nixpkgs.
#
# sst-sqe's bamboo.sh loads its MPI, compiler and tool versions with
# `module load`; sqe-modulefiles.nix provides such modules from Nix.
# The shell function is set up by sourcing $out/lmod/lmod/init/bash (or the
# file for another shell).
{
  lib,
  stdenv,
  fetchFromGitHub,
  lua5_4,
  tcl,
  pkg-config,
  bc,
  procps,
  perl,
  less,
  coreutils,
}:

let
  lua = lua5_4.withPackages (ps: [
    ps.luaposix
    ps.luafilesystem
  ]);
in
stdenv.mkDerivation (finalAttrs: {
  pname = "lmod";
  version = "9.4.5";

  src = fetchFromGitHub {
    owner = "TACC";
    repo = "Lmod";
    tag = finalAttrs.version;
    hash = "sha256-aT4gW9IIiAl4r+H8pTs0jDS5CgfA1TYjc9B27BV3G64=";
  };

  nativeBuildInputs = [
    pkg-config
    perl # pod2man
    lua
  ];

  buildInputs = [
    lua
    tcl
    bc
    procps
    less
  ];

  # init/bash runs `PATH=/bin:/usr/bin stat`.
  postPatch = ''
    patchShebangs proj_mgmt
    substituteInPlace init/bash.in \
      --replace-fail "PATH=/bin:/usr/bin stat" "${coreutils}/bin/stat"
  '';

  configureFlags = [
    "--with-lua=${lua}/bin/lua"
    "--with-luac=${lua}/bin/luac"
    # Interpret TCL modulefiles in process, through the tcl library.
    "--with-fastTCLInterp=yes"
  ];

  enableParallelBuilding = true;

  # The version-independent path the init scripts are known by.
  passthru.initDir = "${finalAttrs.finalPackage}/lmod/lmod/init";

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    export HOME="$TMPDIR"
    mkdir --parents mf/hello
    echo 'setenv("LMOD_NIX_TEST", "yes")' > mf/hello/1.0.lua
    bash -c '
      set -e
      source "$1"
      export MODULEPATH="$PWD/mf"
      module avail
      module load hello/1.0
      test "$LMOD_NIX_TEST" = yes
    ' bash $out/lmod/lmod/init/bash
    runHook postInstallCheck
  '';

  meta = {
    description = "Lua based environment module system";
    homepage = "https://github.com/TACC/Lmod";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
