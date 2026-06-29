{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  setuptools,
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
  version ? "0.6.1",
  hash ? "sha256-EVh6Js+6nxMqyFImEoCyxiO1XJHxCEvjo8BFyRX5/3Q=",
}:

buildPythonPackage {
  pname = "flooNoC";
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

  meta = {
    description = "Python package for the PULP FlooNoC interconnect generator";
    homepage = "https://github.com/pulp-platform/FlooNoC";
    license = lib.licenses.asl20;
    platforms = lib.platforms.unix;
  };
}
