# accelergy-library-plug-in — the `Library` estimator.
#
# Accelergy discovers plug-ins by scanning a share directory rather than by
# import, so installing the Python package is not enough — the estimator's
# .estimator.yaml and its data have to land where Accelergy looks.
{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  accelergy,
  pyyaml,
  version ? "0.1-unstable-2026-02-07",
  rev ? "ba4e9dac1b2e7a3076fb8b7816a5228211623055",
  hash ? "sha256-RbeHQm46HdkGHob/Od8FCVkqP97WHrPHPRCPZ9jZ76c=",
}:

buildPythonPackage {
  pname = "accelergy-library-plug-in";
  inherit version;
  format = "setuptools";

  src = fetchFromGitHub {
    owner = "Accelergy-Project";
    repo = "accelergy-library-plug-in";
    inherit rev hash;
  };

  propagatedBuildInputs = [
    accelergy
    pyyaml
  ];

  doCheck = false;
  # Deliberately no pythonImportsCheck on a plug-in name: Accelergy loads these
  # by scanning, not by import. The real check is whether `estimator: Library`
  # appears in a generated ERT, which needs a full run.

  passthru = {
    nixchipCI = true;
    nixchipUpdate = true;
  };

  meta = {
    description = "Accelergy library-based energy estimation plug-in";
    homepage = "https://github.com/Accelergy-Project/accelergy-library-plug-in";
    license = lib.licenses.mit;
  };
}
