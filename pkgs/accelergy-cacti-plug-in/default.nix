# accelergy-cacti-plug-in — the CactiSRAM/CactiDRAM estimators.
#
# The awkward one: its get_cacti_dir searches for `cacti/cacti` or `cacti`
# relative to os.path.dirname(__file__), so the binary must live *inside* the
# installed plug-in directory — on PATH is not enough (read from the wrapper's
# source, not assumed).
#
# nixchip's cacti is what makes this work: its tech_params and contention.dat
# lookups are patched to absolute store paths, and it ships those data files
# under share/cacti so they can travel with the binary.
{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  accelergy,
  pyyaml,
  cacti,
  version ? "0.1-unstable-2026-02-07",
  rev ? "7649b2c02a389f3c3d585d7ff4ececacfb01e6ea",
  hash ? "sha256-IPA5OLM9Srqh5d8j/QNauPOwaCE8ft0kzQ57Zz4+qDM=",
}:

buildPythonPackage {
  pname = "accelergy-cacti-plug-in";
  inherit version;
  format = "setuptools";

  src = fetchFromGitHub {
    owner = "Accelergy-Project";
    repo = "accelergy-cacti-plug-in";
    inherit rev hash;
  };

  propagatedBuildInputs = [
    accelergy
    pyyaml
  ];

  # Upstream's setup.py copies cacti/cacti as a data file: the plug-in is
  # *meant* to ship a CACTI binary, and its Docker image builds one into the
  # source tree before installing. A fresh checkout has no such file, so the
  # build fails with "can't copy 'cacti/cacti'". Supply nixchip's instead of
  # building a second copy.
  preBuild = ''
    mkdir -p cacti
    cp ${cacti}/bin/cacti cacti/cacti
    chmod +w cacti/cacti
    # CACTI reads its technology tables relative to its own binary, so
    # tech_params/ and contention.dat must travel with it. Without them CACTI
    # produces nothing and Accelergy reports "Can not find an energy estimator
    # for DRAM(...)" — which reads as a missing plug-in rather than a plug-in
    # whose data files are absent.
    cp -r ${cacti}/share/cacti/tech_params cacti/
    cp ${cacti}/share/cacti/contention.dat cacti/
    chmod -R +w cacti
  '';

  postInstall = ''
    plugin_dir="$out/share/accelergy/estimation_plug_ins/accelergy-cacti-plug-in"
    if [ ! -d "$plugin_dir/tech_params" ]; then
      echo "CACTI tech_params did not land beside the binary; every estimate will fail" >&2
      exit 1
    fi
    if [ ! -x "$plugin_dir/cacti" ]; then
      echo "CACTI binary did not land beside the wrapper; get_cacti_dir() will not find it" >&2
      exit 1
    fi
  '';

  doCheck = false;
  # No import check: Accelergy loads this by scanning; the meaningful check is
  # `estimator: CactiSRAM` in a generated ERT, which needs a full run.

  passthru.nixchipCI = true;

  meta = {
    description = "Accelergy CACTI-backed energy estimation plug-in";
    homepage = "https://github.com/Accelergy-Project/accelergy-cacti-plug-in";
    license = lib.licenses.mit;
  };
}
