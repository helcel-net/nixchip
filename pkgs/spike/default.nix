{
  fetchFromGitHub,
  spike,
  nix-update-script,
  version ? "unstable-2026-10-13",
  rev ? "f8a060b7bea8da6f738f193ed1b66b665978d092",
  hash ? "sha256-W0wDTCRczSMyMe6um7o80LpfvuiHDb1MgAB8jxamyN4=",
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
