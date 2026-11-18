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
  version ? "0.1.3",
  hash ? "sha256-jd+V3QuzZsnXqHZDquCQypl+Aly8l7A+1TyrpWFAvcM=",
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

  passthru.nixchipUpdate = true;
  passthru.nixchipUpdateFlags = [ "--version=stable" ];

  meta = {
    description = "Python bindings for flexfloat";
    homepage = "https://github.com/colluca/pyflexfloat";
    license = lib.licenses.asl20;
    platforms = lib.platforms.unix;
  };
}
