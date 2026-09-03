{
  fetchFromGitHub,
  spike,
  nix-update-script,
  version ? "unstable-2026-09-02",
  rev ? "4ffd6ba860f4190ceac2716fa3c2cf139e85538f",
  hash ? "sha256-gpE8T+MOCvcXU5Z5GouALrFpTej3LezzbpTAl9zw8DY=",
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
