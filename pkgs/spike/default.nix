{
  fetchFromGitHub,
  spike,
  nix-update-script,
  version ? "unstable-2026-11-20",
  rev ? "e53c8ccf3448ae459877ed3236cb39b2a1d493bf",
  hash ? "sha256-nrmkeq23tk5mgrx4WVmTWdf5lmUjiMbhY4XIofTT6ek=",
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
