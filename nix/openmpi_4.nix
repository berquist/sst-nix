# Open MPI 4.1.4, the version that sst-sqe/dev/run-bamboo-like-github.sh
# loads as the module mpi/openmpi-4.1.4 (see sqe-modulefiles.nix).
#
# The nixpkgs recipe is for 5.x.  4.1 has its own runtime (ORTE) and bundles
# PMIx 3, so the external PRRTE and PMIx of the recipe are left out.
{
  lib,
  fetchurl,
  openmpi,
  pmix,
  prrte,
}:

openmpi.overrideAttrs (
  finalAttrs: previousAttrs: {
    version = "4.1.4";

    src = fetchurl {
      url = "https://download.open-mpi.org/release/open-mpi/v${lib.versions.majorMinor finalAttrs.version}/openmpi-${finalAttrs.version}.tar.bz2";
      hash = "sha256-kpEuF1/RI0NoyHMMA/SZb+WULnR5ux0QBZQF5/Kzkw0=";
    };

    # libfabric 2 no longer defines container_of, which the OFI MTL takes from
    # it.  Open MPI 4.1.7 defines it itself; this is the same definition.
    postPatch =
      previousAttrs.postPatch
      + ''
        substituteInPlace ompi/mca/mtl/ofi/mtl_ofi_request.h \
          --replace-fail '#include "mtl_ofi.h"' '#include "mtl_ofi.h"
        #include <stddef.h>
        #ifndef container_of
        #define container_of(ptr, type, field) ((type *) ((char *) (ptr) - offsetof(type, field)))
        #endif'
      ''
      # Current GCC refuses the forced inlining of the OFI MTL callbacks
      # ("inlining failed in call to always_inline ... recursive inlining").
      + ''
        substituteInPlace ompi/mca/mtl/ofi/mtl_ofi.h \
          --replace-fail "__opal_attribute_always_inline__" ""
      '';

    # 4.1 also has the ortecc compiler wrapper, a link to opal_wrapper, and
    # orte-info, which prints the configure line; the recipe moves
    # opal_wrapper and ompi_info to the dev output.
    postInstall = previousAttrs.postInstall + ''
      moveToOutput "bin/ortecc" "''${!outputDev}"
      moveToOutput "share/openmpi/ortecc-wrapper-data.txt" "''${!outputDev}"
      moveToOutput "bin/orte-info" "''${!outputDev}"
    '';

    # In 4.1, bin/mpirun is a link to orterun, which remove-references-to
    # does not follow.
    postFixup =
      lib.replaceStrings [ "$out/bin/mpirun" ] [ "$(readlink -f $out/bin/mpirun)" ]
        previousAttrs.postFixup;

    buildInputs = lib.filter (
      p:
      !(builtins.elem p [
        pmix
        prrte
      ])
    ) previousAttrs.buildInputs;

    configureFlags =
      lib.filter (
        flag: !(lib.hasPrefix "--with-pmix" flag || lib.hasPrefix "--with-prrte" flag)
      ) previousAttrs.configureFlags
      ++ [ "--with-pmix=internal" ];

    meta = previousAttrs.meta // {
      description = "Open source MPI-3 implementation (4.1 series)";
    };
  }
)
