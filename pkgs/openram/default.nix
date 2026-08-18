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
  version ? "unstable-2026-08-18",
  rev ? "b2b069ce119d1488cbe6883b2240bceb5c7ce29a",
  hash ? "sha256-YvRqwaRAu6TEd4Uytg90iJiVEff8dhcY9qdMITzl/QY=",
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
