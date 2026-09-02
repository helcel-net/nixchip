{
  fetchFromGitHub,
  spike,
  nix-update-script,
  version ? "unstable-2026-09-01",
  rev ? "549da3faa97abde20b677708f0b227190e1f9aac",
  hash ? "sha256-4juu5BUjVlsoIngJ9v8mcNeqa32z/4ZuF/DluCxq8aw=",
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
