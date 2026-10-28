# Ramulator 2: modular DRAM simulator, used by the ramulator2 backend of SST
# memHierarchy.  Not in nixpkgs.
#
# The commit and the patch are those of sst-sqe
# (buildsys/deps/bin/sstDep_ramulator2_stabledevel.sh).  The SST frontend
# lives in sst-elements; with `sstFrontend` set it is compiled in, as
# memHierarchy/membackend/ramulator2/Instructions.md says.
#
# Upstream fetches yaml-cpp, spdlog and argparse with CMake FetchContent and
# has no install target.  configure of sst-elements wants DIR/src,
# DIR/ext/{spdlog,yaml-cpp}/include and DIR/libramulator.so, so
# passthru.sstPrefix is such a tree.  The library itself is
# lib/libramulator2.so (see installPhase).
{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  sstFrontend ? null,
}:

let
  # The tags in CMakeLists.txt.
  yaml-cpp-src = fetchFromGitHub {
    owner = "jbeder";
    repo = "yaml-cpp";
    tag = "yaml-cpp-0.7.0";
    hash = "sha256-2tFWccifn0c2lU/U1WNg2FHrBohjx8CXMllPJCevaNk=";
  };
  spdlog-src = fetchFromGitHub {
    owner = "gabime";
    repo = "spdlog";
    tag = "v1.11.0";
    hash = "sha256-kA2MAb4/EygjwiLEjF9EA7k8Tk//nwcKB1+HlzELakQ=";
  };
  argparse-src = fetchFromGitHub {
    owner = "p-ranav";
    repo = "argparse";
    tag = "v2.9";
    hash = "sha256-vbf4kePi5gfg9ub4aP1cCK1jtiA65bUS9+5Ghgvxt/E=";
  };
  so = stdenv.hostPlatform.extensions.sharedLibrary;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "ramulator2";
  version = "2.0-unstable-2025-04-03";

  src = fetchFromGitHub {
    owner = "CMU-SAFARI";
    repo = "ramulator2";
    rev = "011ccd77ff7788a35812fbe0446f5f327497022d";
    hash = "sha256-18hRVfQNlHyu1c5oXRnvkgbHxfcTpL7wv+vL4T+c6Gc=";
  };

  # buildsys/deps/patches/ramulator2.patch of sst-sqe: `.template as<T>()`
  # for a dependent YAML node type.  The file has CRLF line endings, which
  # the patch has not.
  postPatch = ''
    substituteInPlace src/base/param.h \
      --replace-fail "return _config[_name].as<T>();" "return _config[_name].template as<T>();"
  '';

  preConfigure = ''
    mkdir --parents ext
    cp --recursive ${yaml-cpp-src} ext/yaml-cpp
    cp --recursive ${spdlog-src} ext/spdlog
    cp --recursive ${argparse-src} ext/argparse
    chmod --recursive u+w ext
    # yaml-cpp 0.7.0 takes uint16_t from <cstdint> without including it,
    # which GCC 13 and later no longer do for it.
    sed --in-place '1i #include <cstdint>' ext/yaml-cpp/src/emitterutils.cpp
    # The fmt 9.1.0 of spdlog checks a format string with a second view of
    # the literal.  Clang (22 at least) takes two evaluations of a literal
    # as two objects (CWG2765), so the pointer difference between the views is
    # not a constant expression.  Check the view that is parsed.  The
    # headers go to $out too, for sst-elements.
    substituteInPlace ext/spdlog/include/spdlog/fmt/bundled/core.h \
      --replace-fail "detail::parse_format_string<true>(str_, checker(s, {}));" \
                     "detail::parse_format_string<true>(str_, checker(str_, {}));"
    # FetchContent uses these in place of downloads; it wants absolute paths.
    cmakeFlagsArray+=(
      "-DFETCHCONTENT_SOURCE_DIR_YAML-CPP=$PWD/ext/yaml-cpp"
      "-DFETCHCONTENT_SOURCE_DIR_SPDLOG=$PWD/ext/spdlog"
      "-DFETCHCONTENT_SOURCE_DIR_ARGPARSE=$PWD/ext/argparse"
    )
  ''
  + lib.optionalString (sstFrontend != null) ''
    cp ${sstFrontend} src/frontend/impl/external_wrapper/sst_frontend.cpp
    sed --in-place '\#impl/external_wrapper/gem5_frontend.cpp#a impl/external_wrapper/sst_frontend.cpp' \
      src/frontend/CMakeLists.txt
  '';

  nativeBuildInputs = [ cmake ];

  cmakeFlags = [
    (lib.cmakeBool "FETCHCONTENT_FULLY_DISCONNECTED" true)
    # yaml-cpp 0.7.0 asks for an older CMake.
    (lib.cmakeFeature "CMAKE_POLICY_VERSION_MINIMUM" "3.5")
  ];

  # The library is written to the source directory.
  installPhase = ''
    runHook preInstall
    install -D --mode=755 ramulator2 $out/bin/ramulator2
    # The build tree RPATH points at the source directory.
    rpath="$(patchelf --print-rpath $out/bin/ramulator2 | tr ':' '\n' | grep --invert-match "^$NIX_BUILD_TOP" | paste --serial --delimiters=:)"
    patchelf --set-rpath "$out/lib''${rpath:+:$rpath}" $out/bin/ramulator2
    # Ramulator 1 also installs libramulator.so, without SONAME either, and
    # memHierarchy links both: give this one its own name, so that the two
    # DT_NEEDED entries differ.
    install -D --mode=755 ../libramulator${so} $out/lib/libramulator2${so}
    patchelf --set-soname libramulator2${so} $out/lib/libramulator2${so}
    patchelf --replace-needed libramulator${so} libramulator2${so} $out/bin/ramulator2
    mkdir --parents $out/include/ramulator2 $out/share/ramulator2/sst/ext
    (cd ../src && find . -name '*.h' -exec install -D --mode=644 {} $out/include/ramulator2/{} \;)
    cp --recursive ../ext/spdlog/include $out/include/ramulator2/spdlog-include
    cp --recursive ../ext/yaml-cpp/include $out/include/ramulator2/yaml-cpp-include
    cp ../example_config.yaml ../example_inst.trace $out/share/ramulator2/
    cd $out/share/ramulator2/sst
    ln --symbolic ../../../include/ramulator2 src
    # configure wants libramulator.so and links -lramulator.
    ln --symbolic ../../../lib/libramulator2${so} libramulator${so}
    ln --symbolic ../../../lib/libramulator2${so} libramulator2${so}
    mkdir --parents ext/spdlog ext/yaml-cpp
    ln --symbolic ../../../../../include/ramulator2/spdlog-include ext/spdlog/include
    ln --symbolic ../../../../../include/ramulator2/yaml-cpp-include ext/yaml-cpp/include
    runHook postInstall
  '';

  # The example configuration and trace of the repository.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    cd $out/share/ramulator2
    $out/bin/ramulator2 -f example_config.yaml
    cd -
    runHook postInstallCheck
  '';

  passthru.sstPrefix = "${finalAttrs.finalPackage}/share/ramulator2/sst";

  meta = {
    description = "Modular and extensible DRAM simulator";
    homepage = "https://github.com/CMU-SAFARI/ramulator2";
    license = lib.licenses.mit;
    mainProgram = "ramulator2";
    platforms = lib.platforms.unix;
  };
})
