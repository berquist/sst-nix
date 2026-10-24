{
  description = "Packages and dev shells for the Structural Simulation Toolkit (SST)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";
    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };

    # Sources for the SST packages.  `just nix-build` replaces them with the
    # local checkouts in this directory.
    sst-core = {
      url = "github:sstsimulator/sst-core/devel";
      flake = false;
    };
    sst-elements = {
      url = "github:sstsimulator/sst-elements/devel";
      flake = false;
    };
    sst-macro = {
      url = "github:sstsimulator/sst-macro/devel";
      flake = false;
    };
    sst-hgcc = {
      url = "github:sstsimulator/sst-hgcc/devel";
      flake = false;
    };
    juno = {
      url = "github:sstsimulator/juno/master";
      flake = false;
    };
    sst-external-element = {
      url = "github:sstsimulator/sst-external-element/master";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      ...
    }@inputs:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        inherit (nixpkgs) lib;
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ self.overlays.default ];
          # Intel Pin, and CUDA (for GPGPU-Sim and balar).
          config.allowUnfreePredicate =
            pkg:
            lib.getName pkg == "intel-pin"
            || builtins.any (license: (license.shortName or "") == "CUDA EULA") (
              lib.toList (pkg.meta.license or [ ])
            );
        };
        # Only those that build on this platform (PEBIL is x86_64 only).
        packages = lib.filterAttrs (_: lib.meta.availableOn pkgs.stdenv.hostPlatform) {
          inherit (pkgs)
            sst-core
            sst-elements
            sst-elements-full-free
            sst-macro
            sst-macro-standalone
            sst-hgcc
            juno
            sst-external-element
            sst-with-elements
            # Dependencies nixpkgs lacks
            sst-dumpi
            ramulator
            ramulator2
            goblin-hmcsim
            otf
            epa-inst-libs
            pebil
            lmod
            # sst-sqe
            openmpi_4
            sqe-modulefiles
            vanadis-cross-compilers
            ;
          blessings = pkgs.python3Packages.blessings;
          default = pkgs.sst-with-elements;
        };
        # Unfree; not in checks.
        unfreePackages = lib.optionalAttrs (lib.meta.availableOn pkgs.stdenv.hostPlatform pkgs.intel-pin) {
          inherit (pkgs)
            intel-pin
            gpgpu-sim
            sst-elements-full
            sqe-modulefiles-full
            ;
        };
        shells = pkgs.callPackage ./nix/shells.nix { };
      in
      {
        packages = packages // unfreePackages;
        devShells = {
          inherit (shells) default;
        }
        // lib.optionalAttrs (unfreePackages != { }) { inherit (shells) full; };
        checks = packages // {
          # The scripts must pass shellcheck and shfmt (.editorconfig).
          scripts =
            pkgs.runCommand "scripts-lint"
              {
                nativeBuildInputs = [
                  pkgs.shellcheck
                  pkgs.shfmt
                ];
              }
              ''
                cp -r ${./scripts} scripts
                cp ${./.editorconfig} .editorconfig
                shellcheck scripts/*.sh
                shfmt --diff scripts/*.sh
                touch $out
              '';
        };
        formatter = pkgs.nixfmt;
      }
    )
    // {
      overlays.default = import ./nix/overlay.nix inputs;
    };
}
