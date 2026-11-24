{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  nix-update-script,
  poetry-core,
  click,
  pyyaml,
  rich,
  httpx,
  pcpp,
  zstandard,
  version ? "unstable-2026-11-24",
  rev ? "7bd69733de6bff7d541cb4295dddc5856e618d0b",
  hash ? "sha256-9u0gnZGP8d7yvDSZy6wWPMBzL4RW5ISbjqTCAYPx+o0=",
}:

buildPythonPackage {
  pname = "ciel";
  inherit version;

  src = fetchFromGitHub {
    owner = "fossi-foundation";
    repo = "ciel";
    inherit rev hash;
  };

  pyproject = true;

  build-system = [ poetry-core ];

  dependencies = [
    click
    pyyaml
    rich
    httpx
    pcpp
    zstandard
  ];

  pythonImportsCheck = [ "ciel" ];

  passthru = {
    updateScript = nix-update-script {
      attrPath = "ciel";
      extraArgs = [ "--version=branch" ];
    };
    nixchipUpdate = true;
    nixchipCI = true;
  };

  meta = {
    description = "PDK builder and version manager for PDKs in the open_pdks format";
    homepage = "https://github.com/fossi-foundation/ciel";
    license = lib.licenses.asl20;
    mainProgram = "ciel";
    platforms = lib.platforms.unix;
  };
}
