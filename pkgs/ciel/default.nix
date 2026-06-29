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
  version ? "unstable-2026-06-27",
  rev ? "a28c4c0f9f496c8e5bd7c4c03db349094f5aa286",
  hash ? "sha256-koN65VQLGXvVmVd8hNJvbDn7R/4EHg/sNaHvWDWW4DM=",
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
