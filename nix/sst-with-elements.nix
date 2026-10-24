# sst-core together with a set of element libraries, like
# python3.withPackages: `sst-with-elements.override { elements = [ ... ]; }`.
#
# Each element package installs a sstsimulator.conf fragment (sst-elements
# also one in its `testsuite` output).  This package merges them with the conf of
# sst-core into etc/sst/sstsimulator.conf and wraps the programs:
#   sst, sst-info, ...   SST_CONFIG_FILE_PATH points at the merged conf, and
#                        PYTHONPATH has the Python packages of the elements
#   sst-test-core,       read <bindir>/../etc/sst/sstsimulator.conf, so they
#   sst-test-elements    work from bin/ as links
{
  lib,
  symlinkJoin,
  makeWrapper,
  python3,
  sst-core,
  elements ? [ ],
  # Also merge the test suite paths, for sst-test-elements.
  withTests ? true,
}:

let
  confOf = pkg: lib.optional (pkg ? sstConf) "${pkg}/${pkg.sstConf}";
  testsConfOf =
    pkg: lib.optional (withTests && pkg ? testsuite && pkg ? sstConf) "${pkg.testsuite}/${pkg.sstConf}";
  confs = [
    "${sst-core}/etc/sst/sstsimulator.conf"
  ]
  ++ lib.concatMap (e: confOf e ++ testsConfOf e) elements;

  pythonEnvs = lib.filter (p: p != null) (map (e: e.pythonEnv or null) elements);
  pythonPath = lib.concatMapStringsSep ":" (p: "${p}/${p.sitePackages}") pythonEnvs;

  names = lib.concatMapStringsSep "-" (e: e.pname or e.name) elements;
in
symlinkJoin {
  name = "sst-with-elements-${sst-core.version}";

  paths = [ sst-core ] ++ elements;

  nativeBuildInputs = [ makeWrapper ];

  postBuild = ''
    rm $out/etc/sst/sstsimulator.conf
    ${python3.interpreter} ${./merge-sst-conf.py} $out/etc/sst/sstsimulator.conf $out/bin ${lib.escapeShellArgs confs}

    for program in sst sst-info sst-config sst-register; do
      rm $out/bin/$program
      makeWrapper ${sst-core}/bin/$program $out/bin/$program \
        --set SST_CONFIG_FILE_PATH $out/etc/sst/sstsimulator.conf \
        ${lib.optionalString (pythonPath != "") "--prefix PYTHONPATH : ${pythonPath}"}
    done
  '';

  passthru = {
    inherit sst-core elements;
    # The conf fragments that went into etc/sst/sstsimulator.conf.
    inherit confs;
  };

  meta = sst-core.meta // {
    description = "Structural Simulation Toolkit with element libraries (${names})";
  };
}
