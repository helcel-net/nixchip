{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  nix-update-script,
  setuptools,
  numpy,
  scipy,
  matplotlib,
  scikit-learn,
  coverage,
  version ? "unstable-2026-11-10",
  rev ? "2f7b3866418ac1ce17ad959207a1489033d8c577",
  hash ? "sha256-kaNO6gORiYCeDmfFcmo5UGcj3cRQHl6Bs4B1iIjxXH8=",
}:

buildPythonPackage {
  pname = "openram";
  inherit version;

  src = fetchFromGitHub {
    owner = "VLSIDA";
    repo = "openram";
    inherit rev hash;
  };

  pyproject = true;
  build-system = [ setuptools ];

  dependencies = [
    numpy
    scipy
    matplotlib
    scikit-learn
    coverage
  ];

  pythonRemoveDeps = [
    "python-subunit"
    "unittest2"
    "volare"
    "ciel"
  ];

  postPatch = ''
    patchShebangs .
  '';

  doCheck = false;

  postInstall = ''
    mkdir -p $out/share/openram
    cp -r $src/* $out/share/openram
    rm -f $out/share/openram/install_conda.sh
    substituteInPlace $out/share/openram/compiler/sram_config.py \
      --replace-fail 'tentative_num_rows < 16' 'tentative_num_rows < 4'
  '';

  passthru = {
    updateScript = nix-update-script {
      attrPath = "openram";
      extraArgs = [ "--version=branch" ];
    };
    nixchipUpdate = true;
    nixchipCI = true;
  };

  meta = {
    description = "An open-source static random access memory (SRAM) compiler";
    homepage = "https://github.com/VLSIDA/openram";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.unix;
  };
}
