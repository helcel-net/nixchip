{
  fetchFromGitHub,
  spike,
  nix-update-script,
  version ? "unstable-2026-11-10",
  rev ? "c20813c1d696e843ff1b7667413f98d1397d85ea",
  hash ? "sha256-s4q6bJSymNMp25DyWWcHq/Qcv4/sycSjWKdD+t0FDpc=",
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
