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
  version ? "unstable-2026-10-13",
  rev ? "d2af9cd676810db6ac7e15895a3285bf7d06034c",
  hash ? "sha256-bARqe8Mu15bIlb0I+UK5feefN1qXRngBB2r3kgwxI7w=",
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
