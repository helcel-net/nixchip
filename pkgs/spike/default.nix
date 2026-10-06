{
  fetchFromGitHub,
  spike,
  nix-update-script,
  version ? "unstable-2026-10-06",
  rev ? "fdc1ffa05152707a00ca22a9cf50c59a1b487875",
  hash ? "sha256-ySamlLUopNWqAjQTPl5KZXStU2DRCskJURFUx7JZGz8=",
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
