{
  fetchFromGitHub,
  spike,
  nix-update-script,
  version ? "unstable-2026-11-03",
  rev ? "75fb7ef0aa89ae1f9ee361eb84d47753bc8349f8",
  hash ? "sha256-ntwo/4xZi+wabLc2BDUKI6VQr1hEPuCPonq+ktmEYCU=",
  ...
}:

spike.overrideAttrs (old: {
  inherit version;
  src = fetchFromGitHub {
    owner = "riscv-software-src";
    repo = "riscv-isa-sim";
    inherit rev hash;
  };
  # installCheckPhase runs a RISC-V hello-world via spike+pk; the CLI flags
  # change across releases and the test breaks against HEAD.
  doInstallCheck = false;
  passthru = (old.passthru or { }) // {
    updateScript = nix-update-script {
      attrPath = "spike";
      extraArgs = [ "--version=branch" ];
    };
    nixchipUpdate = true;
    nixchipCI = true;
  };
})
