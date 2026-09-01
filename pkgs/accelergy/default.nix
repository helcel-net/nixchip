# accelergy 0.4 — the energy-estimation framework Timeloop's v4 front-end sits
# on. nixpkgs ships 0.1-unstable, which timeloopfe cannot use: it imports
# accelergy.utils.yaml, and in 0.1 accelergy.utils is not a package.
#
# Deps are the ones the accelergy-timeloop-infrastructure Docker image reports
# for 0.4 (`pip show accelergy`): deepdiff, Jinja2, pyfiglet, pyYAML,
# ruamel.yaml.
{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  deepdiff,
  jinja2,
  pyfiglet,
  pyyaml,
  ruamel-yaml,
  version ? "0.4-unstable-2025-05-26",
  rev ? "6911d15686ee7efdceba7d95605102df4472ae3a",
  hash ? "sha256-YgJbmxJfuw7jk+Ssj5r3cmJYSSepf7aw+Ti3a9brm6o=",
}:

buildPythonPackage {
  pname = "accelergy";
  inherit version;
  format = "setuptools";

  src = fetchFromGitHub {
    owner = "Accelergy-Project";
    repo = "accelergy";
    inherit rev hash;
  };

  propagatedBuildInputs = [
    deepdiff
    jinja2
    pyfiglet
    pyyaml
    ruamel-yaml
  ];

  # Upstream has no test suite runnable without estimation plug-ins installed.
  doCheck = false;
  pythonImportsCheck = [
    "accelergy"
    "accelergy.utils"
    "accelergy.utils.yaml"
  ];

  passthru = {
    nixchipCI = true;
    nixchipUpdate = true;
  };

  meta = {
    description = "Architecture-level energy estimation framework";
    homepage = "https://github.com/Accelergy-Project/accelergy";
    license = lib.licenses.mit;
  };
}
