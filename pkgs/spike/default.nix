{
  fetchFromGitHub,
  spike,
  nix-update-script,
  version ? "unstable-2026-10-23",
  rev ? "2c300cd90eb74bb79f3fcdd58596a6f8d842d01c",
  hash ? "sha256-yeyyR/hWMvgJeyZ/n5N/uJLVAw1NbBMgy7dpLllL4K0=",
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
