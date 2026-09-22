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
  version ? "unstable-2026-09-22",
  rev ? "1d2526e67a062ac408166a51183222e281a7b9a3",
  hash ? "sha256-qJ14rnR9FJ4DXPIhnJfUbuZUjde6V8AOcoP16mKwXuA=",
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
