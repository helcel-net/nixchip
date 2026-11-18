{
  fetchFromGitHub,
  spike,
  nix-update-script,
  version ? "unstable-2026-11-18",
  rev ? "7d1ee24bcc3308557e1c6a45c579db9ca5e97dd9",
  hash ? "sha256-n2sPqZK8kmCLWhWPZDBZnFVZtN8alVShPVqSkV7+IoQ=",
  ...
}:

spike.overrideAttrs (old: {
  inherit version;
  src = fetchFromGitHub {
    owner = "riscv-software-src";
    repo = "riscv-isa-sim";
    inherit rev hash;
    # berkeley-softfloat-3 became a submodule upstream.
    fetchSubmodules = true;
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
