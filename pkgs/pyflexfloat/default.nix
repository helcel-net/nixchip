{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  setuptools,
  setuptools-scm,
  wheel,
  numpy,
  cffi,
  flexfloat,
  version ? "0.1.2",
  hash ? "sha256-MYgIRpOpJfCbIJ4HtAVeLrTXZ7wRhH6hHlOhCRkWTbE=",
}:

buildPythonPackage {
  pname = "pyflexfloat";
  inherit version;

  src = fetchFromGitHub {
    owner = "colluca";
    repo = "pyflexfloat";
    rev = version;
    inherit hash;
  };

  pyproject = true;

  build-system = [
    setuptools
    setuptools-scm
    wheel
  ];

  dependencies = [
    numpy
    cffi
  ];

  postUnpack = ''
    cp -r ${flexfloat}/* $sourceRoot/flexfloat
  '';

  postPatch = ''
    substituteInPlace setup.py \
      --replace-warn "['cmake', '..']" "['echo', '1']"
  '';

  meta = {
    description = "Python bindings for flexfloat";
    homepage = "https://github.com/colluca/pyflexfloat";
    license = lib.licenses.asl20;
    platforms = lib.platforms.unix;
  };
}
