{
  fetchFromGitHub,
  spike,
  nix-update-script,
  version ? "unstable-2026-06-26",
  rev ? "55b4658dbf574ba0b714083ec436ce2cb5be1998",
  hash ? "sha256-re0Gb4iKLcybbE+ZV/TXe2M0tIHQOCgCkwQjdnwUX/c=",
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
