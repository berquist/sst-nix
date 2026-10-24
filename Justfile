# Tasks for the SST checkouts in this directory.  Recipes run in the dev
# shell (direnv or `nix develop`); the *-full recipes switch to the full
# shell themselves.  Output goes to build/ and install/.

set shell := ["bash", "-euo", "pipefail", "-c"]

# List the recipes
default:
    @just --list

# --- Local builds ------------------------------------------------------------

# Build and install one checkout into install/<project>
build project *configure_args:
    scripts/build.sh {{ project }} {{ configure_args }}

# Build core, elements (all free optional dependencies), macro and hgcc
build-all: (build "sst-core") (build "sst-elements") (build "sst-macro") (build "sst-hgcc") (build "juno") (build "sst-external-element")

# Build sst-elements with the unfree dependencies too (Pin, CUDA, GPGPU-Sim)
build-elements-full *configure_args:
    nix develop .#full --command scripts/build.sh sst-elements {{ configure_args }}

# Run sst-test-core or sst-test-elements against install/
test suite *args:
    scripts/test.sh {{ suite }} {{ args }}

# --- sst-sqe -------------------------------------------------------------------

# Run sst-sqe/dev/run-bamboo-like-github.sh as is, into a log file
sqe *log:
    scripts/sqe.sh {{ log }}

# --- Nix -----------------------------------------------------------------------

# Build a flake package from the local checkouts
nix-build pkg="sst-with-elements" *args:
    scripts/nix-build-local.sh {{ pkg }} {{ args }}

# Build and test all packages and lint the scripts
check:
    nix flake check --print-build-logs
