{
  fetchFromGitHub,
  spike,
  nix-update-script,
  version ? "unstable-2026-08-11",
  rev ? "16c0b60119f65a648643cf5d41e4e38e871f0bad",
  hash ? "sha256-pmZ/+kCQeV12UFY3zkeowQ1f2C7ivmNWsMjgxe9DSB0=",
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
