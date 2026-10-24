# Lmod modulefiles for sst-sqe/buildsys/bamboo.sh, which loads MPI and tool
# versions by module name.  Point MODULEPATH at $out.
#
#   mpi/openmpi-4.1.4   the MPI_TYPE of dev/run-bamboo-like-github.sh
#   ccache/ccache-V     bamboo.sh tries ccache/ccache-4.12 and goes on
#   otf2/otf2-V         without it; these carry the real versions
#   pin/pin-V           only with pinSupport (the full shell)
{
  lib,
  runCommand,
  writeText,
  openmpi_4,
  ccache,
  otf2,
  intel-pin,
  pinSupport ? false,
}:

let
  modulefile =
    {
      description,
      pkg,
      family ? null,
      bins ? [ (lib.getBin pkg) ],
      env ? { },
    }:
    writeText "modulefile.lua" (
      ''
        whatis("${description}")
        help([[${description} (${pkg.name}, from Nix)]])
      ''
      + lib.optionalString (family != null) ''
        family("${family}")
      ''
      + lib.concatMapStrings (bin: ''
        prepend_path("PATH", "${bin}/bin")
      '') bins
      + lib.concatStrings (
        lib.mapAttrsToList (name: value: ''
          setenv("${name}", "${value}")
        '') env
      )
    );

  modules = {
    "mpi/openmpi-${openmpi_4.version}" = modulefile {
      description = "Open MPI ${openmpi_4.version}";
      pkg = openmpi_4;
      family = "mpi";
      # mpicc and friends are in the dev output.
      bins = [
        (lib.getBin openmpi_4)
        (lib.getDev openmpi_4)
      ];
      env.MPIHOME = "${lib.getDev openmpi_4}";
    };
    "ccache/ccache-${ccache.version}" = modulefile {
      description = "ccache ${ccache.version}";
      pkg = ccache;
    };
    "otf2/otf2-${otf2.version}" = modulefile {
      description = "OTF2 ${otf2.version}";
      pkg = otf2;
      env.OTF2_INSTALL_PREFIX = "${lib.getDev otf2}";
    };
  }
  // lib.optionalAttrs pinSupport {
    "pin/pin-${intel-pin.version}" = modulefile {
      description = "Intel Pin ${intel-pin.version}";
      pkg = intel-pin;
      env.INTEL_PIN_DIRECTORY = "${intel-pin}";
    };
  };
in
runCommand "sqe-modulefiles" { passthru = { inherit modules; }; } (
  lib.concatStrings (
    lib.mapAttrsToList (name: file: ''
      install -D --mode=644 ${file} $out/${name}.lua
    '') modules
  )
)
