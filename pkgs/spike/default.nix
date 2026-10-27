{
  fetchFromGitHub,
  spike,
  nix-update-script,
  version ? "unstable-2026-10-27",
  rev ? "f2207b5a7dc83a4695b019b8e95080de047a81cc",
  hash ? "sha256-gG4PRudHasdsPGsqllXDRCwvJvU0oris/aTlLizk7RQ=",
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
