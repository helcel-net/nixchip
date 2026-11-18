{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  setuptools,
  uv-build,
  wheel,
  mako,
  hjson,
  jsonref,
  pylint,
  pytest,
  pygame,
  pydantic,
  ruamel-yaml,
  click,
  networkx,
  matplotlib,
  version ? "0.9.0",
  hash ? "sha256-Ohi0qRnV3vNCwXw40hZ7Hcw0o+x8SnEIwUGaUq1Kcq8=",
}:

buildPythonPackage {
  # The distribution is "floogen" since 0.9.0 (previously "flooNoC").
  pname = "floogen";
  inherit version;

  src = fetchFromGitHub {
    owner = "pulp-platform";
    repo = "FlooNoC";
    rev = "v${version}";
    inherit hash;
  };

  pyproject = true;

  build-system = [
    setuptools
    uv-build
    wheel
  ];

  dependencies = [
    mako
    hjson
    jsonref
    pylint
    pytest
    pygame
    pydantic
    ruamel-yaml
    click
    networkx
    matplotlib
  ];

  doCheck = false;

  passthru.nixchipCI = true;
  passthru.nixchipUpdate = true;
  passthru.nixchipUpdateFlags = [ "--version=stable" ];

  meta = {
    description = "Python package for the PULP FlooNoC interconnect generator";
    homepage = "https://github.com/pulp-platform/FlooNoC";
    license = lib.licenses.asl20;
    platforms = lib.platforms.unix;
  };
}
