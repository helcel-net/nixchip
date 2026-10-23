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
  version ? "unstable-2026-10-23",
  rev ? "d2eb3cf1c43f0f8522e93c537f8fca50781216d5",
  hash ? "sha256-IEeNYjmA7geiHCVzjadDzy77STbbWmie47HF63bqMqk=",
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
