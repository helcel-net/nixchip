{
  fetchFromGitHub,
  spike,
  nix-update-script,
  version ? "unstable-2026-09-22",
  rev ? "19609434bb3d83448eec8796e8f0367c868efbda",
  hash ? "sha256-r3T9beOHQebgVHrZhNNFAH703zhFONBW6uKsa7xPfCg=",
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
