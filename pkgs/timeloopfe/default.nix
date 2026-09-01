# timeloopfe — Timeloop's v4 Python front-end. The intended way to drive
# Timeloop v4: Specification.from_yaml_files(...) then call_mapper(...). Pure
# Python, no ext_modules.
#
# Pinned to the commit the accelergy-timeloop-infrastructure Docker image's
# submodule records, not `main` — a moving ref with a fixed hash is a build
# that breaks the day upstream pushes, and this stack exists to reproduce that
# image's numbers.
{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  accelergy,
  ruamel-yaml,
  psutil,
  joblib,
  version ? "0.4-unstable-2025-01-23",
  rev ? "5603893c0ff75183b5ffd6839aba33774fc3b6fe",
  hash ? "sha256-/HO6QOoB9sUv2WztH+54Y9EahpKRmvx1+dRFTT27kXQ=",
}:

buildPythonPackage {
  pname = "timeloopfe";
  inherit version;
  format = "setuptools";

  src = fetchFromGitHub {
    owner = "Accelergy-Project";
    repo = "timeloopfe";
    inherit rev hash;
  };

  propagatedBuildInputs = [
    accelergy
    ruamel-yaml
    psutil
    joblib
  ];

  # Upstream ships no test suite runnable without Timeloop's binaries.
  doCheck = false;
  pythonImportsCheck = [
    "timeloopfe"
    "timeloopfe.v4"
  ];

  passthru = {
    nixchipCI = true;
    nixchipUpdate = true;
  };

  meta = {
    description = "Python front-end for Timeloop v4 specifications";
    homepage = "https://github.com/Accelergy-Project/timeloopfe";
    license = lib.licenses.mit;
  };
}
